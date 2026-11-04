package vn.drinkstore.common;

public final class PhoneNumbers {
    private PhoneNumbers() {}
    public static final String OPTIONAL_PATTERN = "(?:[0-9]{10,11})?";
    public static final String MESSAGE = "Số điện thoại phải gồm đúng 10 hoặc 11 chữ số.";
    public static void validate(Object phone, boolean required) {
        String value = phone == null ? "" : phone.toString();
        if ((!value.isEmpty() || required) && !value.matches("[0-9]{10,11}"))
            throw ApiException.bad(MESSAGE);
    }
}
