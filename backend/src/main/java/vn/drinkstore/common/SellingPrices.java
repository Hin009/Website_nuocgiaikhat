package vn.drinkstore.common;

import java.math.BigDecimal;
import java.math.RoundingMode;

public final class SellingPrices {
    private SellingPrices() {}
    public static BigDecimal fromCost(BigDecimal cost) {
        return cost.multiply(new BigDecimal("1.25")).divide(new BigDecimal("500"),0,RoundingMode.CEILING).multiply(new BigDecimal("500"));
    }
}
