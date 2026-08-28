    floating_point
    integer
    complex
    boolean
}

    float_16
    b_float_16
    float_32
    float_64
    int_8
    u_int_8
    int_16
    u_int_16
    int_32
    u_int_32
    int_64
    u_int_64
    bool
    complex_64
    complex_128
    float_8_e_4_m_3_fn
    float_8_e_5_m_2
    custom
}
interface id_type {
    name() . string
    category() . DTypeCategory
    size_bytes() . i64
    is_floating_point() . bool
    is_integer() . bool
    is_signed() . bool
    equals(other: DType) . bool
}

struct dtype_promotion_rule {
    DType from_dtype
    DType to_dtype
    i64 cost
}
interface id_type_promotion {
    promote(dtype1: DType, dtype2: DType) . DType
    get_promotion_chain(from_dtype: DType, to_dtype: DType) . []d_type
    can_promote(from_dtype: DType, to_dtype: DType) . bool
    promotion_cost(from_dtype: DType, to_dtype: DType) . i64
}
interface id_type_registry {
    register_dtype(string name, i64 size, category: DTypeCategory) . DType
    register_promotion_rule(rule: dtype_promotion_rule) . void
    get_all_promotion_rules() . []dtype_promotion_rule
}
interface id_type_casting {
    cast(input: tensor, target_dtype: DType) . tensor
    is_safe_cast(from_dtype: DType, to_dtype: DType) . bool
    cast_cost(from_dtype: DType, to_dtype: DType) . i64
}
interface id_type_format_conversion {
    convert_dtype(tensor: tensor, target_dtype: DType) . tensor
    saturate_on_cast(tensor: tensor, target_dtype: DType) . tensor
    bitcast(tensor: tensor, target_dtype: DType) . tensor
}
