package vn.drinkstore.purchasing;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import vn.drinkstore.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;

class ImportPackagingTest {
    @Test void acceptsExistingPackagesAndExplicitPackOrCaseFactors() {
        assertDoesNotThrow(()->ImportPackaging.validate(new PurchaseController.Line(1,10,BigDecimal.TEN)));
        for(String packaging:new String[]{"LOC","THUNG"})
            assertDoesNotThrow(()->ImportPackaging.validate(new PurchaseController.Line(null,2,BigDecimal.TEN,1L,packaging,48)));
    }
    @Test void rejectsAmbiguousOrMissingConversionInformation() {
        assertThrows(ApiException.class,()->ImportPackaging.validate(new PurchaseController.Line(1L,2,BigDecimal.TEN,1L,"LOC",6)));
        assertThrows(ApiException.class,()->ImportPackaging.validate(new PurchaseController.Line(null,2,BigDecimal.TEN,null,"THUNG",24)));
        for(Integer factor:new Integer[]{null,0,1,1000001})
            assertThrows(ApiException.class,()->ImportPackaging.validate(new PurchaseController.Line(null,2,BigDecimal.TEN,1L,"THUNG",factor)));
        assertThrows(ApiException.class,()->ImportPackaging.validate(new PurchaseController.Line(null,2,BigDecimal.TEN,1L,"INVALID",24)));
    }
}
