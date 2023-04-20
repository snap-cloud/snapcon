require "test_helper"

class CurrencyConversionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @currency_conversion = currency_conversions(:one)
  end

  test "should get index" do
    get currency_conversions_url
    assert_response :success
  end

  test "should get new" do
    get new_currency_conversion_url
    assert_response :success
  end

  test "should create currency_conversion" do
    assert_difference("CurrencyConversion.count") do
      post currency_conversions_url, params: { currency_conversion: {  } }
    end

    assert_redirected_to currency_conversion_url(CurrencyConversion.last)
  end

  test "should show currency_conversion" do
    get currency_conversion_url(@currency_conversion)
    assert_response :success
  end

  test "should get edit" do
    get edit_currency_conversion_url(@currency_conversion)
    assert_response :success
  end

  test "should update currency_conversion" do
    patch currency_conversion_url(@currency_conversion), params: { currency_conversion: {  } }
    assert_redirected_to currency_conversion_url(@currency_conversion)
  end

  test "should destroy currency_conversion" do
    assert_difference("CurrencyConversion.count", -1) do
      delete currency_conversion_url(@currency_conversion)
    end

    assert_redirected_to currency_conversions_url
  end
end
