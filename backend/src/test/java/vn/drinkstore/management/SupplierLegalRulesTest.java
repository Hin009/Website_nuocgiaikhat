package vn.drinkstore.management;

import org.junit.jupiter.api.Test;
import vn.drinkstore.common.ApiException;
import static org.junit.jupiter.api.Assertions.*;

class SupplierLegalRulesTest {
    @Test void normalizesBranchCodesAndPreservesLeadingZero() {
        assertEquals("0123456789",SupplierLegalRules.taxCode("DOANH_NGHIEP","0123456789"));
        assertEquals("0123456789-001",SupplierLegalRules.taxCode("DOANH_NGHIEP","0123456789001"));
        assertEquals("0123456789-001",SupplierLegalRules.taxCode("DOANH_NGHIEP","0123456789-001"));
    }
    @Test void personalIdentifiersApplyOnlyToHouseholdsAndIndividuals() {
        for(String type:new String[]{"CA_NHAN","HO_KINH_DOANH"}) {
            assertEquals("012345678901",SupplierLegalRules.taxCode(type,"012345678901"));
            assertEquals("0123456789",SupplierLegalRules.taxCode(type,"0123456789"));
        }
        assertThrows(ApiException.class,()->SupplierLegalRules.taxCode("DOANH_NGHIEP","012345678901"));
    }
    @Test void allowsPendingProfilesWithoutInventingTaxCodes() {
        assertNull(SupplierLegalRules.taxCode("DOANH_NGHIEP",null));
        assertNull(SupplierLegalRules.taxCode("CA_NHAN",""));
        for(String code:new String[]{"123","ABC1234567","0123456789--001","0123456789 001"})
            assertThrows(ApiException.class,()->SupplierLegalRules.taxCode("DOANH_NGHIEP",code));
    }
}
