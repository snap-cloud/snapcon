function checkboxSwitch(selector){
  $(selector).bootstrapSwitch();

  // Prevent duplicated event handlers when the page is re-rendered.
  $(selector).off('switchChange.bootstrapSwitch');
  $(selector).off('.osemSwitchGuard');

  // Mark as user-initiated before bootstrapSwitch triggers switchChange.
  // Important: bootstrapSwitch often binds clicks on its generated wrapper/label,
  // so we must listen on those too (not only on the hidden checkbox input).
  $(selector).each(function() {
    var $input = $(this);
    $input.data('osem-user-toggle', false);

    var $wrapper = $input.closest('.bootstrap-switch');
    if ($wrapper.length === 0) {
      $wrapper = $input.parent();
    }

    $wrapper.off('click.osemSwitchGuard mouseup.osemSwitchGuard touchend.osemSwitchGuard pointerup.osemSwitchGuard');
    $wrapper.on(
      'click.osemSwitchGuard mouseup.osemSwitchGuard touchend.osemSwitchGuard pointerup.osemSwitchGuard',
      function() {
        $input.data('osem-user-toggle', true);
      }
    );
  });

  $(selector).on('switchChange.bootstrapSwitch', function(_event, state) {
    var $el = $(this);
    if (!$el.data('osem-user-toggle')) {
      return;
    }

    // bootstrapSwitch can emit multiple switchChange events per user click.
    // Delay the request slightly, then read the final checkbox state to send once.
    var existingTimer = $el.data('osem-user-toggle-timer');
    if (existingTimer) {
      clearTimeout(existingTimer);
    }

    var method = $el.attr('method') || 'patch';
    var urlBase = $el.attr('url');

    var timer = setTimeout(function() {
      $el.data('osem-user-toggle', false);

      var checked = $el.is(':checked');
      var url = urlBase + (checked ? 'true' : 'false');

      $.ajax({
        url: url,
        type: method,
        dataType: 'script'
      });
    }, 180);

    $el.data('osem-user-toggle-timer', timer);
  });
}

$(function () {
  $.fn.bootstrapSwitch.defaults.onColor = 'success';
  $.fn.bootstrapSwitch.defaults.offColor = 'warning';
  $.fn.bootstrapSwitch.defaults.onText = 'Yes';
  $.fn.bootstrapSwitch.defaults.offText = 'No';
  $.fn.bootstrapSwitch.defaults.size = 'small';


  checkboxSwitch("[class='switch-checkbox']");

  $("[class='switch-checkbox-schedule']").bootstrapSwitch();

  $('input[class="switch-checkbox-schedule"]').on('switchChange.bootstrapSwitch', function(event, state) {
    var url = $(this).attr('url');
    var method = $(this).attr('method') || 'patch';

    if(state){
      url += $(this).attr('value');
    }

    var callback = function(data) {
      showError($.parseJSON(data.responseText).errors);
    }
    $.ajax({
      url: url,
      type: method,
      error: callback,
      dataType: 'json'
    });
  });
});
