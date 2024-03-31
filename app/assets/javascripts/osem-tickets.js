function update_price($this){

    var id = $this.data('id');
    var selectedCurrency = $('#currency_selector').val();
    var conversionData = window.currencyRates[selectedCurrency] || { rate: 1, symbol: '$' };
    var conversionRate = conversionData.rate;

    var originalPrice = parseFloat($('#price_'+id).data('original-price'));
    var convertedPrice = originalPrice*conversionRate;

    // Calculate price for row
    $('#currency_symbol_' + id).text(conversionData.symbol);
    $('#total_currency_symbol_' + id).text(conversionData.symbol);
    $('#price_' + id).text(convertedPrice.toFixed(2));
    $('#total_row_' + id).text((convertedPrice * $this.val()).toFixed(2));

    // Calculate total price
    var total = 0;
    $('.total_row').each(function() {
        total += parseFloat($(this).text().trim());
    });
    $('#total_currency_symbol').text(conversionData.symbol);
    $('#total_price').text(total.toFixed(2));
}

$( document ).ready(function() {

    window.currencyRates = {};
    if (window.currencyMeta) {
        window.currencyMeta.forEach(function(currencyInfo) {
            window.currencyRates[currencyInfo.currency] = { rate: currencyInfo.rate, symbol: currencyInfo.symbol };
        });
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
    
    $('#currency_selector').change(function() {
        $('.quantity').each(function() {
            update_price($(this));
        });
    });
});
