
function update_currency_rates(data) {
    data.forEach(function(conversion) {
        var key = conversion.from_currency + "_to_" + conversion.to_currency;
        window.currencyRates[key] = { rate: conversion.rate, symbol: conversion.symbol };
    });
    $('.quantity').each(function() {
        update_price($(this));
    });
}

function fetch_currency_rates(){
    //todo get conference dynamically
    var conferenceIdentifier = $('meta[name="conference-short-title"]').data('short-title');
    var requestUrl = "/admin/conferences/" + conferenceIdentifier + "/currency_conversions";
    $.ajax({
        url: requestUrl, 
        type: "GET",
        dataType: "json",
        success: function(data) {
            update_currency_rates(data);
        },
        error: function(xhr, status, error) {
          console.error("Failed to fetch currency rates: " + error);
        }
    });
    
}

function update_price($this){

    var id = $this.data('id');

    var selectedCurrency = $('#currency_selector').val();
    var baseCurrency = "USD"; // todo fetch from controller
    var conversionKey = baseCurrency + "_to_" + selectedCurrency;
    var conversionData = window.currencyRates[conversionKey] || { rate: 1, symbol: '$' };
    var conversionRate = conversionData.rate;

    var originalPrice = parseFloat($('#price_'+id).data('original-price'));
    var convertedPrice = originalPrice*conversionRate;


    // Calculate price for row
    var value = $this.val();
    $('#price_' + id).text(conversionData.symbol + " " + convertedPrice.toFixed(2));


    $('#total_row_' + id).text(conversionData.symbol + " " + (value * convertedPrice).toFixed(2));

    // Calculate total price
    var total = 0;
    $('.total_row').each(function( index ) {
        //a bit hacky, look into setting symbol as an attribute by itself instead of concatenating
        total += parseFloat($(this).text().replace(conversionData.symbol, '').trim());
    });
    $('#total_price').text(conversionData.symbol + total.toFixed(2));
}

$( document ).ready(function() {

    // Initialize currency conversion rates
    window.currencyRates = {};

    if($('#currency_selector').length > 0) {
        fetch_currency_rates();
    }

    $('.quantity').each(function() {
        update_price($(this));
    });

    $('.quantity').change(function() {
        update_price($(this));
    });
    $(function () {
      $('[data-toggle="tooltip"]').tooltip()
    });
    

    // Add change event listener to currency selector
    $('#currency_selector').change(function() {
        $('.quantity').each(function() {
            update_price($(this));
        });
    });
});
