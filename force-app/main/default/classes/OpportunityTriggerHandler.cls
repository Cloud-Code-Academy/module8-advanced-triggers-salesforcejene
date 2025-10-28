public with sharing class OpportunityTriggerHandler extends TriggerHandler{

    //instantiate class variabes as references to the trigger context variables
    private List<Opportunity>   newOpps    = new List<Opportunity>();
    private List<Opportunity>   oldOpps    = new List<Opportunity>();
    private Map<Id,Opportunity> newOppsMap = new Map<Id,Opportunity>();
    private Map<Id,Opportunity> oldOppsMap = new Map<Id,Opportunity>();
    // private context TriggerContext = this.context;
    static Boolean hasFired = false;  //The flag is used to prevent recursion

    public OpportunityTriggerHandler(List<Opportunity> newOpps, List<Opportunity> oldOpps, Map<Id,Opportunity> newOppsMap, Map<Id,Opportunity> oldOppsMap) {

        this.newOpps    = newOpps;
        this.oldOpps    = oldOpps;
        this.newOppsMap = newOppsMap;
        this.oldOppsMap = oldOppsMap;
    }

    public override void beforeUpdate() {
        for (Opportunity opp : this.newOpps) {
            if (opp.Amount < 5000) {
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
        OpportunityTriggerHelper.appendStageChangeToDescription(newOpps, oldOppsMap);
    }
 
    public override void beforeDelete() {
        // Prevent deletion of closed Opportunities
        for (Opportunity oldOpp : this.oldOpps) {
            if (oldOpp.IsClosed) {
                oldOpp.addError('Cannot delete closed opportunity');
            }
        }
        OpportunityTriggerHelper.verifyClosedWonBankingOpps(oldOpps);
    }

    public override void beforeInsert(){
        // Set default Type for new Opportunities
        for(Opportunity opp : this.newOpps) {
            if (opp.Type == null) {
                opp.Type = 'New Customer';
            }
        }
    }

    public override void afterInsert(){
        if (hasFired) {
            return;
        }
        hasFired = true;

        System.debug('Trigger context was :+) ' + Trigger.operationType);
        OpportunityTriggerHelper.buildNewTasksForOpps(newOpps);
        OpportunityTriggerHelper.addPrimaryContactToOpportunities(newOpps, 'CEO');
        hasFired = false;   //reset
    }

    public override void afterUpdate(){
        if (hasFired){
            return;
        }
        hasFired = true;        
        System.debug('Trigger context was : ' + Trigger.operationType);
        OpportunityTriggerHelper.addPrimaryContactToOpportunities(newOpps, 'CEO');
        hasFired = false;   //reset flag
    }

    public override void afterDelete() {
        OpportunityTriggerHelper.notifyOwnersOpportunityDeleted(oldOpps);
    }
    
    public override void afterUndelete() {
        if (hasFired) {
            return;
        }
        hasFired = true;
        if (Trigger.isAfter && Trigger.isUndelete){
            OpportunityTriggerHelper.addPrimaryContactToOpportunities(newOppsMap.values(), 'VP Sales');
        }
        hasFired = false;   //flag reset 
    }
}