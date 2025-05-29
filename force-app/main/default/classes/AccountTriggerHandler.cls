public with sharing class AccountTriggerHandler extends TriggerHandler {

    private List<Account>  newAccounts;
    private Map<Id,Account> newAccountMap;


    public AccountTriggerHandler (List<Account> newAccounts, Map<Id,Account> newAccountMap) {
        this.newAccounts = newAccounts;
        this.newAccountMap = newAccountMap;
    }

    
    public override void beforeInsert() {
        //mark blank Type records as Prospect

        for (Account acc : this.newAccounts) {
            if (acc.Type == null) {
                acc.Type = 'Prospect';                
            }
            //set Account Type as Hot if certain fields are populated.
            if (acc.Phone   != null && 
                acc.Website != null && 
                acc.Fax     != null) 
                {
                acc.Rating  = 'Hot';
            }
            //call setShipping
            setShippingAddress();
        }
    }

    public override void afterInsert() {
        //Add default contacts to newly inserted accounts
        List<Contact> conList = new List<Contact>();
        for (Account newAcc : this.newAccounts) {

            Contact con = new Contact(

            LastName    = 'DefaultContact',
            Email       = 'default@email.com',
            AccountId   = newAcc.Id);
            //add record(s) to list
            conlist.add(con);
        }
        Database.insert(conList, AccessLevel.USER_MODE);
    }

    public void setShippingAddress() {
        //Set shipping Address to Billing if Shipping is not null
        for (Account acc : this.newAccounts) {

            if (acc.ShippingStreet != null) {
                acc.BillingStreet = acc.ShippingStreet;
            }
    
            if (acc.ShippingCity != null) {
                acc.BillingCity = acc.ShippingCity;
            }
    
            if (acc.ShippingState != null) {
                acc.BillingState = acc.ShippingState;
            }
    
            if (acc.ShippingPostalCode != null) {
                acc.BillingPostalCode = acc.ShippingPostalCode;
            }
    
            if (acc.ShippingCountry != null) {
                acc.BillingCountry = acc.ShippingCountry;
            }            
        }       
    }
}