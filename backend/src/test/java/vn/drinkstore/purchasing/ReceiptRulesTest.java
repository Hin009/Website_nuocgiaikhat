package vn.drinkstore.purchasing;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import vn.drinkstore.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;

class ReceiptRulesTest {
    @Test void allowsEntirelyRejectedDeliveryButRequiresReason() {
        assertDoesNotThrow(()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,0,new BigDecimal("10000"),10,"Broken packaging")));
        assertThrows(ApiException.class,()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,0,new BigDecimal("10000"),10," ")));
    }
    @Test void rejectsEmptyAndNegativeDeliveries() {
        assertThrows(ApiException.class,()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,0,BigDecimal.ZERO)));
        assertThrows(ApiException.class,()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,-1,BigDecimal.ZERO,1,"Broken")));
        assertDoesNotThrow(()->ReceiptRules.validate(new PurchaseController.ReceiptLine(1,98,new BigDecimal("10000"),2,"Broken")));
    }

}
