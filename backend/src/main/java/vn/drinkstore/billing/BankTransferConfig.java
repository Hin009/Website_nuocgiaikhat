package vn.drinkstore.billing;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import vn.drinkstore.common.ApiException;

@Component
public record BankTransferConfig(
    @Value("${app.bank-transfer.bank-id:}") String bankId,
    @Value("${app.bank-transfer.bank-name:}") String bankName,
    @Value("${app.bank-transfer.account-number:}") String accountNumber,
    @Value("${app.bank-transfer.account-name:}") String accountName) {
    public BankTransferConfig {
        bankId=bankId.trim(); bankName=bankName.trim(); accountNumber=accountNumber.trim(); accountName=accountName.trim();
    }
    public boolean ready() { return !bankId.isBlank() && !accountNumber.isBlank() && !accountName.isBlank(); }
    public void requireReady() { if(!ready()) throw ApiException.bad("Cửa hàng chưa cấu hình tài khoản chuyển khoản. Vui lòng chọn COD."); }
    public Map<String,String> details() { return Map.of("bankId",bankId,"bankName",bankName,"accountNumber",accountNumber,"accountName",accountName); }
}
