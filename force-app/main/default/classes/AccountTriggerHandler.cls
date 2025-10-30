public with sharing class AccountTriggerHandler extends TriggerHandler {

    private List<Account>   newAccounts     = new List<Account>();
    private List<Account>   oldAccounts     = new List<Account>();
    private Map<Id,Account> newAccountMap   = new Map<Id,Account>();
    private Map<Id,Account> oldAccountMap   = new Map<Id,Account>();
    
    public AccountTriggerHandler (List<Account> newAccounts, Map<Id,Account> newAccountMap) {
        this.newAccounts = newAccounts;
        this.newAccountMap = newAccountMap;
    }
    
    public override void beforeInsert() {
        AccountTriggerHelper.setTypeProspect(newAccounts);
        AccountTriggerHelper.setShippingInfo(newAccounts);
    }

    public override void afterInsert() {
        AccountTriggerHelper.defineDefaultContact(newAccounts);
    }
}