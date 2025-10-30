public with sharing class AccountTriggerHelper {

    public static void setTypeProspect (List<Account> newAccs){
        //mark blank Type records as Prospect
        for (Account acc : newAccs) {
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
        }
    }
            
    public static void setShippingInfo(List<Account> newAccs){
        for (Account acc : newAccs){
            //Set shipping Address to Billing if Shipping is not null
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

    public static void defineDefaultContact(List<Account> newAccs){
        
        //Add default contacts to newly inserted accounts
        List<Contact> conList = new List<Contact>();
        for (Account newAcc : newAccs) {

            Contact con = new Contact(
            LastName    = 'DefaultContact',
            Email       = 'default@email.com',
            AccountId   = newAcc.Id);
            //add record(s) to list
            conlist.add(con);
        }
        Database.insert(conList, AccessLevel.USER_MODE);
    }
}