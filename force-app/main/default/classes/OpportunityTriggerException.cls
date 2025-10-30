public with sharing class OpportunityTriggerException extends Exception {

    public static String AMOUNT_TOO_LOW = 'Opportunity amount must be greater than 5000';
    public static String CANNOT_DELETE_WON_BANKING_OPPS = 'Cannot delete closed opportunity for a banking account that is won';
}