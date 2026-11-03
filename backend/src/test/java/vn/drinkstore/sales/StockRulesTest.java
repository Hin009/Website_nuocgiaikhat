package vn.drinkstore.sales;

import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import vn.drinkstore.common.ApiException;

class StockRulesTest {
    private Map<String,Object> line(int quantity,int factor,int stock) {
        return Map.of("available",true,"san_pham_id",1L,"so_luong",quantity,"he_so_quy_doi",factor,"so_luong_co_ban",stock,"ten","Coca-Cola");
    }
    @Test void aggregatesDifferentPackagesOfSameProduct() {
        // 1 case of 24 + 2 cans exceeds 25 cans although each line alone is valid.
        assertThrows(ApiException.class,()->CartService.validateStock(List.of(line(1,24,25),line(2,1,25))));
    }
    @Test void acceptsExactAvailableQuantity() { assertDoesNotThrow(()->CartService.validateStock(List.of(line(1,24,26),line(2,1,26)))); }
    @Test void rejectsHiddenProduct() {
        var l=new HashMap<>(line(1,1,10)); l.put("available",false);
        assertThrows(ApiException.class,()->CartService.validateStock(List.of(l)));
    }
}
