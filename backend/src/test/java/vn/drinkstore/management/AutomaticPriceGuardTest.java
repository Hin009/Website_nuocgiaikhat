package vn.drinkstore.management;

import java.math.BigDecimal;
import java.util.Map;
import org.junit.jupiter.api.Test;
import vn.drinkstore.common.ApiException;
import vn.drinkstore.security.Access;
import static org.junit.jupiter.api.Assertions.*;

class AutomaticPriceGuardTest {
    private final ManagementService service=new ManagementService(null,new Access(null) {
        @Override public boolean admin() { return true; }
    });
    @Test void adminCannotSetPriceThroughProductEditor() {
        var request=new ManagementController.ProductEditor("Drink","Brand",1,"330ml","",new BigDecimal("12000"),true,1L,"LON",null,null,null,null);
        assertThrows(ApiException.class,()->service.productEditor(1L,request));
        assertThrows(ApiException.class,()->service.productEditor(null,request));
    }
    @Test void genericPackageEndpointsCannotSetCostOrPrice() {
        for(String field:new String[]{"gia_ban","gia_von"}) {
            assertThrows(ApiException.class,()->service.save("packages",1L,Map.of(field,12000)));
            assertThrows(ApiException.class,()->service.save("packages",null,Map.of(field,12000)));
        }
    }
    @Test void newProductsCannotHaveUncostedOpeningStock() {
        var request=new ManagementController.ProductEditor("Drink","Brand",1,"330ml","",null,true,null,"LON",null,10L,null,"Opening count");
        assertThrows(ApiException.class,()->service.productEditor(null,request));
    }
}
