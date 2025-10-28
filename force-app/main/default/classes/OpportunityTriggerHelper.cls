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
    //The opps param is generalized based on the trigger context
    public static void addPrimaryContactToOpportunities (List<Opportunity> opps, String contactTitle){
        Set<Id> acctIds = new Set<Id>();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Opportunity opp : opps){
            if (opp.AccountId != null) {
                acctIds.add(opp.AccountId);
            }
        }
        //find matching contacts related to the above accounts. These will be stored as Primary Contact on the opportunity 
        Map <Id,Account> primaryContactMap = new Map <Id,Account>([
            SELECT Id,
                (SELECT Id, AccountId
                FROM Contacts
                WHERE Title = :contactTitle
                ORDER BY CreatedDate DESC
                LIMIT 1)
            FROM Account
            WHERE Id IN :acctIds
            WITH USER_MODE
        ]);
        // //Populate the CEO contact from related Acct
        for (Opportunity opp : opps) {            
            if (opp.AccountId != null && primaryContactMap.containsKey(opp.AccountId)) {

                Account acct = primaryContactMap.get(opp.AccountId);
                List<Contact> newestMatchingContact = acct.Contacts; //point to subquery records

                if (newestMatchingContact != null && !newestMatchingContact.isEmpty()){
                    Contact match = newestMatchingContact[0];  //use the newest contact

                    If(opp.Primary_Contact__c == null){
                        oppsToUpdate.add(new Opportunity (
                            Id = opp.Id,
                            Primary_Contact__c = match.Id              
                        ));
                    }
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
}