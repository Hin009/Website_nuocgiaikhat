package vn.drinkstore.common;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class SellingPricesTest {
    @Test void roundsMarkedUpPricesUpToFiveHundredDong() {
        for(String[] example:new String[][]{{"11666.67","15000"},{"58333.33","73000"},{"8666.67","11000"},{"10000","12500"},{"0","0"}})
            assertEquals(0,new BigDecimal(example[1]).compareTo(SellingPrices.fromCost(new BigDecimal(example[0]))));
    }
}
