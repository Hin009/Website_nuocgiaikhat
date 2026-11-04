package vn.drinkstore.common;

import jakarta.validation.Validation;
import org.junit.jupiter.api.Test;
import vn.drinkstore.auth.AuthController;
import vn.drinkstore.customer.CustomerController;
import vn.drinkstore.administration.AdminController;
import vn.drinkstore.management.ManagementController;
import static org.junit.jupiter.api.Assertions.*;

class PhoneNumbersTest {
    @Test void exactDigitLengthsAreEnforcedOnEveryPublicPhoneDto() {
        try(var factory=Validation.buildDefaultValidatorFactory()) {
            var validator=factory.getValidator();
            for(String phone:new String[]{"0900000000","01234567890","123456789","123456789012","+84900000000","090 0000000","090000000x"}) {
                boolean valid=phone.matches("[0-9]{10,11}");
                Object[] requests={
                    new AuthController.Register("user@test.invalid","TestPass123!","User",phone),
                    new CustomerController.Profile("User",phone,null),
                    new CustomerController.Address("User",phone,"HCM",null,null,"123 Street",true),
                    new AdminController.NewStaff("user@test.invalid","TestPass123!","User",phone,null),
                    new AdminController.AccountEditor("user@test.invalid","User",phone,"KHACH_HANG",true,null),
                    new AdminController.StaffProfile("User",null,null,phone,null),
                    new ManagementController.SupplierEditor("Supplier",null,null,phone,null,null,"HOP_TAC","DOANH_NGHIEP","CHUA_XAC_MINH",null,false,null)
                };
                for(Object request:requests) assertEquals(valid,validator.validate(request).isEmpty(),request.getClass().getSimpleName()+" / "+phone);
            }
        }
    }
    @Test void optionalFieldsStayOptionalButCheckoutPhoneIsRequired() {
        assertDoesNotThrow(()->PhoneNumbers.validate(null,false));
        assertDoesNotThrow(()->PhoneNumbers.validate("",false));
        assertThrows(ApiException.class,()->PhoneNumbers.validate("",true));
        assertThrows(ApiException.class,()->PhoneNumbers.validate("123456789",false));
        assertDoesNotThrow(()->PhoneNumbers.validate("01234567890",true));
    }
}
