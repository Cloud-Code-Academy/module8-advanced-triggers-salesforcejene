public with sharing class OpportunityTriggerHandler extends TriggerHandler{

    //instantiate class variabes as references to the trigger context variables
    private List<Opportunity>   newOpps    = new List<Opportunity>();
    private List<Opportunity>   oldOpps    = new List<Opportunity>();
    private Map<Id,Opportunity> newOppsMap = new Map<Id,Opportunity>();
    private Map<Id,Opportunity> oldOppsMap = new Map<Id,Opportunity>();


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
        OpportunityTriggerHelper.addPrimaryCEOContact(newOpps);

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
        System.debug(LoggingLevel.INFO, 'OppTriggerHandler: Begin BEfoRe_INSERT');
        // Set default Type for new Opportunities
        for(Opportunity opp : this.newOpps) {
            if (opp.Type == null) {
                opp.Type = 'New Customer';
            }
        }
    }

    public override void afterInsert(){
        System.debug(LoggingLevel.INFO, 'OppTriggerHandler: Context AFTER_INSERT');
        OpportunityTriggerHelper.buildNewTasksForOpps(newOpps);
    }

    public override void afterUpdate(){
        // Append Stage changes in Opportunity Description
        System.debug('Oppty Code fired in the afterUpdate context.');
    }

    public override void afterDelete() {
        //print message
        System.debug('Who ya gonna call??');
        OpportunityTriggerHelper.notifyOwnersOpportunityDeleted(oldOpps);
    }
}