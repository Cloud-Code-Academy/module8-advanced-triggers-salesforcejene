public with sharing class OpportunityTriggerHelper {

    public static void appendStageChangeToDescription (List<Opportunity> newOpps, Map<Id,Opportunity> oldOppsMap) {
        for (Opportunity opp : newOpps){
            Opportunity oldOpp = oldOppsMap.get(opp.Id);

            if (opp.StageName != null && opp.StageName != oldOpp.StageName){
                opp.Description = (opp.Description == null ? '': opp.Description);
                opp.Description += '\n Stage Change: ' + opp.StageName + ':' + Datetime.now().format();
            }
        }
    }

    public static void addPrimaryCEOContact (List<Opportunity> newOpps){
        Set<Id> acctIds = New Set<Id>();

        for (Opportunity opp : newOpps) {
            acctIds.add(opp.AccountId); 
        }
        //find CEO contacts that will be stored as Primary Contact            
        Map <Id,Id> primaryContactMap = new Map <Id,Id>();

        for (Contact con : [SELECT Id, AccountId
                            FROM Contact
                            WHERE Title = 'CEO'
                            AND AccountId IN :acctIds
                            WITH USER_MODE]) {

            primaryContactMap.put(con.AccountId, con.Id);
        }
        //Populate the CEO contact from related Acct
        for (Opportunity opp :newOpps) {
            if (opp.AccountId != null && primaryContactMap.containsKey(opp.AccountId)) {
                opp.Primary_Contact__c = primaryContactMap.get(opp.AccountId);
            }
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
        ]);
        
        for (Opportunity opp : existingOpps) { 
            if (opp.StageName   == 'Closed Won'){
                String industry = accountsWithOppsMap.get(opp.AccountId).Industry;
                if (industry    == 'Banking') {
                    opp.addError('Cannot delete closed opportunity for a banking account that is won');
                }
            }
        }
    }

    public static void buildNewTasksForOpps (List<Opportunity> oppsNeedingTasks) {
        for(Opportunity opp : oppsNeedingTasks) {
            
            Task tsk = new Task (
                Subject = 'Call Primary Contact',
                WhatId = opp.Id,
                OwnerId = opp.OwnerId,
                ActivityDate = Date.today().addDays(3)
            );}
        Database.insert(oppsNeedingTasks, AccessLevel.USER_MODE);
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

    public static void assignPrimaryContact (Map<Id,Opportunity> undeletedOppsMap){
        //add set to store unique AccoutIds
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : undeletedOppsMap.values()){
            if (opp.AccountId != null && opp.Primary_Contact__c == null) {
                accountIds.add(opp.AccountId);
            }
        }

        //retrieve all VP Sales contacts for the relavant accounts
        Map<Id, Contact> accountIdsWPrimaryContactMap = new Map<Id,Contact>();

        for (Contact con : [SELECT Id, AccountId 
                            FROM Contact
                            WHERE Title = 'VP Sales' 
                            AND AccountId IN :accountIds
                            WITH USER_MODE]) {
            //Only take first contact 
            if(!accountIdsWPrimaryContactMap.containsKey(con.AccountId)){
                accountIdsWPrimaryContactMap.put(con.AccountId, con);
            }
        }

        //now that I have the accountIds and Contacts, need to update the matching opp records
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Opportunity opp : undeletedOppsMap.values()) {
            if(opp.Primary_Contact__c == null && accountIdsWPrimaryContactMap.containsKey(opp.AccountId)){
                oppToUpdate.add (new Opportunity ( 
                    Id = opp.Id,
                    Primary_Contact__c = accountIdsWPrimaryContactMap.get(opp.AccountId).Id
                ));
                oppsToUpdate.add(oppToUpdate);
            }            
        }
        Database.update(oppsToUpdate, AccessLevel.USER_MODE);
    }
}