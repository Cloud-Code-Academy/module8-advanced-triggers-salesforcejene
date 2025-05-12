public with sharing class OpportunityTriggerHandler extends TriggerHandler{

    //instantiate class variabes as references to the trigger contextw variables
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
        // Set default Type for new Opportunities
        for(Opportunity opp : this.newOpps) {
            if (opp.Type == null) {
                opp.Type = 'New Customer';
            }
        }
    }

    public override void afterInsert(){
        OpportunityTriggerHelper.buildNewTasksForOpps(newOpps);
    }

    public override void afterUpdate(){
        // Append Stage changes in Opportunity Description
        for (Opportunity opp : newOpps) {
            Opportunity oldOpp = oldOppsMap.get(opp.Id);

            if (opp.stageName  != null && opp.stageName != oldOpp.StageName) {
                opp.Description = (opp.Description == null ? '' : opp.Description);
                opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
            }
        }            
    }

    public override void afterDelete() {
        OpportunityTriggerHelper.notifyOwnersOpportunityDeleted(oldOpps);
    }
}