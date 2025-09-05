public with sharing class OpportunityTriggerHelper {

    public static void appendStageChangeToDescription (List<Opportunity> newOpps, Map<Id,Opportunity> oldOppsMap) {
        for (Opportunity opp : newOpps){
            Opportunity oldOpp = oldOppsMap.get(opp.Id);
            //if there is data in stageName and there is a new value then; if description is null leave it null or display the Description
            if (opp.StageName != null && opp.StageName != oldOpp.StageName){
                //Assign an empty string to Description prevent concatenation failure
                opp.Description = (opp.Description == null ? '': opp.Description);
                opp.Description += '\n Stage Change:' + opp.StageName;
            }            
        }
    } 

    public static void addPrimaryCEOContactToOpportunities (List<Opportunity> newOpps){
        Set<Id> acctIds = new Set<Id>();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        System.debug('Event that triggered the addPrimaryCEOContact::-): ' + Trigger.operationType);
        //System.debug('context: ' + this.context);

        for (Opportunity opp : newOpps){
            if (opp.AccountId != null) {
                acctIds.add(opp.AccountId);
            }
        }

        System.debug(LoggingLevel.FINEST, 'Total count of opps with related accounts (acctIds) are... ' + acctIds.size());
        System.debug('Value of acctIds is: ' + acctIds);

        //find CEO contacts related to the above accounts. These will be stored as Primary Contact on the opportunity 
        Map <Id,Account> primaryContactMap = new Map <Id,Account>([
            SELECT Id,
                (SELECT Id, AccountId, Name
                FROM Contacts
                WHERE Title = 'CEO')
            FROM Account
            WHERE Id IN :acctIds
            WITH USER_MODE
        ]);

        System.debug(LoggingLevel.FINEST, 'Total count of primary Contacts are... ' + primaryContactMap.size());
        System.debug('Values iin primaryContactMap: ' + primaryContactMap);
        /* final stretch time!! 
        I need a reference to the Account and Contact records*/
        // //Populate the CEO contact from related Acct
        for (Opportunity opp : newOpps) {            
            if (opp.AccountId != null && primaryContactMap.containsKey(opp.AccountId)) {

                Account acct = primaryContactMap.get(opp.AccountId);
                List<Contact> ceoContacts = acct.Contacts; //point to subquery records

                if (ceoContacts != null && !ceoContacts.isEmpty()){
                    Contact ceo = ceoContacts[0];  //use the first record

                    oppsToUpdate.add(new Opportunity (
                    Id = opp.Id,                    
                    Primary_Contact__c = ceo.Id              
                    ));
                }                
            }            
        }
        //run dml to populate
        if (!oppsToUpdate.isEmpty()) {
            Database.update(oppsToUpdate, AccessLevel.USER_MODE);
        }    
    }

    public static void verifyClosedWonBankingOpps (List<Opportunity> existingOpps){
        Map<Id,Account> accountsWithOppsMap = new Map<Id,Account>([
            SELECT Id, Industry
            FROM Account
            WHERE Id IN (
                SELECT AccountId
                FROM Opportunity
                WHERE Id IN :existingOpps)            
            WITH USER_MODE
        ]);
        
        for (Opportunity opp : existingOpps) { 
            if (opp.StageName == 'Closed Won') {
                if(accountsWithOppsMap.containsKey(opp.AccountId)){
                String industry = accountsWithOppsMap.get(opp.AccountId).Industry;
                    if (industry == 'Banking') {
                        opp.addError('Cannot delete closed opportunity for a banking account that is won');
                    }   
                }                
            }
        }
    }

    public static void buildNewTasksForOpps (List<Opportunity> oppsNeedingTasks) {
        List<Task> tasksToInsert = new List<Task>();

        for(Opportunity opp : oppsNeedingTasks) {            
            Task tsk     = new Task (
            Subject      = 'Call Primary Contact',
            WhatId       = opp.Id,
            WhoId        = opp.Primary_Contact__c,
            OwnerId      = opp.OwnerId,
            ActivityDate = Date.today().addDays(3)
            );
            //add task to list. 
            tasksToInsert.add(tsk);
        }
        
        if (!tasksToInsert.isEmpty()){
            Database.insert(tasksToInsert, AccessLevel.USER_MODE);
        }
    }
    

    public static void notifyOwnersOpportunityDeleted (List <Opportunity> deletedOpps) {
        //list to store completed messages
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        
        //Gather unique OwnerIds
        Set<Id> ownerIds = new Set<Id>();
        for (Opportunity opp : deletedOpps) {
            if (opp.OwnerId != null) {
                ownerIds.add(opp.OwnerId);
            }
        }
        //Query user emails
        Map<Id,String> ownerEmailMap = new Map<Id,String>();

        for (User usr : [SELECT Id, Email 
                        FROM User 
                        WHERE Id IN :ownerIds
                        WITH USER_MODE]) {

            if (usr.Email != null) {
                ownerEmailMap.put(usr.Id, usr.Email);
            }
        }

        //group deleted opp names by owner
        Map<Id, List<String>> ownerToOppNames = new Map<Id, List<String>>();
        for (Opportunity opp : deletedOpps){
            /*if this is the first pass for this oppOwner,
            generate a new empty list and store it in the map for that oppOwner
            */
            if(!ownerToOppNames.containsKey(opp.OwnerId)) {
                ownerToOppNames.put(opp.OwnerId, new List<String>());
            }
            //get the list of opp names for that owner & add it to the list            
            ownerToOppNames.get(opp.OwnerId).add(opp.Name);
        }

        //generate email per owner by storing the owner's email
        for (Id ownerId : ownerToOppNames.keySet()){
            String email = ownerEmailMap.get(ownerId);
            If (email == null) {
                continue;
            }

            String body = 'The following opportunities were deleted: \n' + String.join(ownerToOppNames.get(ownerId), email);

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {email});
            mail.setSubject('Deleted Opportunities Alert!');
            mail.setPlainTextBody(body);
            mails.add(mail);
        }
        
        //send emails----
        try {
            if(!mails.isEmpty()){
                Messaging.sendEmail(mails);
            }
            
        } catch (Exception e){
            System.debug('Error sending emails: ' + e.getMessage());
        }
    }
    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted (restored) Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */

    public static void assignPrimaryContact (Map<Id,Opportunity> restoredOppsMap){
        //add sets to store unique AccoutIds and primary contactIds
        Set<Id> accountIds = new Set<Id>();
        Set<Id> primaryContactIds = new Set<Id>();

        System.debug('Event that triggered the assignPrimaryContact :-): ' + Trigger.operationType);
        
        //Gather AccountIds and Primary_Contact__c values from Opportunities
        for (Opportunity opp : restoredOppsMap.values()){

            //find related opps that have an Account
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }

            //query restoredOpps that do not have Primary contacts
            for (Opportunity opps : [SELECT Id, AccountId
                                    FROM Opportunity
                                    WHERE AccountId IN :accountIds]){

                                    }
            //Store all primaryContacts that have been assigned
            ///---THIS IS AN ISSUE-
            if (opp.Primary_Contact__c != null) {
                primaryContactIds.add(opp.Primary_Contact__c);
            }
            System.debug('contents of AccountId :*: '+ accountIds);
            System.debug('contents of PrimaryContactIds: - :'+ primaryContactIds);
        }

        //Find existing contacts (not deleted) that are currently assigned as Primary
        Map<Id,Contact> existingContactsMap = new Map<Id,Contact>([
            SELECT Id
            FROM Contact
            WHERE Id IN :primaryContactIds
            WITH USER_MODE
        ]);
        System.debug(LoggingLevel.ERROR, '🔥 assignPrimaryContact method was called');
        System.debug(LoggingLevel.FINEST, 'Contents of existingContacts: ' + existingContactsMap);

        
        
        // Query all VP Sales contacts for the those accounts
        Map<Id, Contact> vpSalesByAccount = new Map<Id,Contact>();

        for (Contact con : [SELECT Id, AccountId 
                            FROM Contact
                            WHERE Title = 'VP Sales'
                            AND AccountId IN :accountIds
                            WITH USER_MODE
                            ORDER BY FirstName DESC
        ]) {
            System.debug(LoggingLevel.ERROR, '✅ VP Sales contact found: ' + con.Id);
            System.debug(LoggingLevel.FINEST, 'Final vpSalesByAccount-+: ' + vpSalesByAccount);
            //Only take first contact 
            if(!vpSalesByAccount.containsKey(con.AccountId)) {
                vpSalesByAccount.put(con.AccountId, con);
            }
            System.debug('accountIds:+- ' + accountIds);
            System.debug('VP Sales contacts found++::: ' + vpSalesByAccount);
        }

        //now that I have the accountIds and Contacts, need to update the matching opp records
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        //If there is no primaryContact (vp sales) + related accounts are in the map then 
        for (Opportunity opp : restoredOppsMap.values()) {
            //flag when a valid PrimarContact exists
            Boolean hasValidPrimary =  opp.Primary_Contact__c == null || !existingContactsMap.containsKey(opp.Primary_Contact__c);
            
            /* Assign the VP Sales contact as the Primary Contact*/
            if (hasValidPrimary && vpSalesByAccount.containsKey(opp.AccountId)
            && opp.Primary_Contact__c != vpSalesByAccount.get(opp.AccountId).Id) {
                oppsToUpdate.add (new Opportunity ( 
                    Id = opp.Id,
                    Primary_Contact__c = vpSalesByAccount.get(opp.AccountId).Id
                ));
            }
        }
        if (!oppsToUpdate.isEmpty()) {
            Database.update(oppsToUpdate, AccessLevel.USER_MODE);
        }
    }
}