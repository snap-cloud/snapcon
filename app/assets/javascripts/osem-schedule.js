// ADMIN SCHEDULE

var url; // Should be initialize in Schedule.initialize
var schedule_id; // Should be initialize in Schedule.initialize

function showError(error){
  // Delete other error messages before showing the new one
  $('.unobtrusive-flash-container').empty();
  UnobtrusiveFlash.showFlashMessage(error, {type: 'error'});
}

var Schedule = {
  initialize: function(url_param, schedule_id_param) {
    url = url_param;
    schedule_id = schedule_id_param;
  },
  remove: function(element) {
    var e = $("#" + element);
    var event_schedule_id = parseInt(e.attr("event_schedule_id"));
    if(event_schedule_id > 0) {
      var my_url = `${url}/${event_schedule_id}`;
      var success_callback = function(data) {
        e.attr("event_schedule_id", null);
        e.appendTo($(".unscheduled-events"));
        e.find(".schedule-event-delete-button").hide();
      }
      var error_callback = function(data) {
        showError($.parseJSON(data.responseText).errors);
      }
      $.ajax({
        url: my_url,
        type: 'DELETE',
        success: success_callback,
        error: error_callback,
        dataType : 'json'
      });
    }
    else{
      showError("The event couldn't be unscheduled");
    }
  },
  add: function (previous_parent, new_parent, event) {
    event.appendTo(new_parent);
    // Event Schedule Id could be an empty string.
    var event_schedule_id = parseInt(event.attr("event_schedule_id"));
    var my_url = url;
    var type = 'POST';
    var params = { event_schedule: {
      room_id: new_parent.attr("room_id"),
      start_time: (new_parent.attr("date") + ' ' + new_parent.attr("hour"))
    }};
    if (event_schedule_id > 0) {
      type = 'PUT';
      my_url += `/${event_schedule_id}`;
    } else {
      params['event_schedule']['event_id'] = event.attr("event_id");
      params['event_schedule']['schedule_id'] = schedule_id;
    }
    var success_callback = function(data) {
      event.attr("event_schedule_id", data.event_schedule_id);
      event.find(".schedule-event-delete-button").show();
      }
    var error_callback = function(data) {
      showError($.parseJSON(data.responseText).errors);
      event.appendTo(previous_parent);
    }
    $.ajax({
      url: my_url,
      type: type,
      data: params,
      success: success_callback,
      error: error_callback,
      dataType : 'json'
    });
  }
};

$(document).ready( function() {
  // hide the remove button for unscheduled and non schedulable events
  $('.unscheduled-events .schedule-event-delete-button').hide();
  $('.non_schedulable .schedule-event-delete-button').hide();

  $('#current-event-btn').on('click', function() {
    var now = new Date();
    var closestEvent = null;
    var smallestDiff = Infinity;

    $('.event-item').each(function() {
      let $event = $(this), eventTimeStr = $event.data('time');

      if (!eventTimeStr) { return; }

      var eventTime = new Date(eventTimeStr);
      var diff = Math.abs(eventTime - now);
      if (diff < smallestDiff) {
        smallestDiff = diff;
        closestEvent = $event;
      }
    });

    if (closestEventId) {
      // Instead of relying on hash it's probably better to scroll using javascript
      // Since the users and click button->scroll->click again, which won't re-scroll
      $('.highlighted').removeClass('highlighted');
      $(closestEvent).addClass('highlighted').get(0).scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });

  // set events as draggable
  $('.schedule-event').not('.non_schedulable').draggable({
    snap: '.schedule-room-slot',
    revertDuration: 200,
    revert: function (event, ui) {
        return !event;
    },
    stop: function(event, ui) {
        this._originalPosition = this._originalPosition || ui.originalPosition;
        ui.helper.animate( this._originalPosition );
    },
    opacity: 0.7,
    snapMode: "inner",
    zIndex: 2,
    scroll: true
  });

  // set room cells as droppable
  $('.schedule-room-slot').not('.non_schedulable .schedule-room-slot').droppable({
    accept: '.schedule-event',
    tolerance: "pointer",
    drop: function(event, ui) {
        $(ui.draggable).css("left", 0);
        $(ui.draggable).css("top", 0);
        $(this).css("background-color", "#ffffff");
        Schedule.add($(ui.draggable).parent(), $(this), $(ui.draggable));
    },
    over: function(event, ui) {
      $(this).css("background-color", "#009ED8");
    },
    out: function(event, ui) {
      $(this).css("background-color", "#ffffff");
      }
  });
});


// PUBLIC SCHEDULE

function starClicked(e) {
  // stops the click from propagating
  if (!e) var e = window.event;
  e.preventDefault();
  e.cancelBubble = true;
  if (e.stopPropagation) e.stopPropagation();

  var callback = function(data) {
    $(e.target).toggleClass('fa-solid fa-regular');
  }

  var params = { favourite_user_id: $(e.target).data('user') };

  $.ajax({
    url: $(e.target).data('url'),
    type: 'PATCH',
    data: params,
    success: callback,
    dataType : 'json'
  });
}

function eventClicked(e, element) {
  if (e.target.href) {
    return;
  }
  var url = $(element).data('url');
  if (e.ctrlKey || e.metaKey) {
    window.open(url, '_blank');
  } else {
    window.location = url;
  }
}

function updateFavouriteStatus(options) {
  if (options.loggedIn === false) {
    $('.js-toggleEvent').hide();
  }

  options.events.forEach(function (id) {
    $(`#eventFavourite-${id}`).removeClass('fa-regular').addClass('fa-solid');
  });
}

/* Links inside event-panel (to make ctrl + click work for these links):
 = link_to text, '#', onClick: 'insideLinkClicked();', 'data-url' => url
*/
function insideLinkClicked(event) {
  // stops the click from propagating
  if (!event) // for IE
    var event = window.event;
  event.cancelBubble = true;
  if (event.stopPropagation) event.stopPropagation();

  var url = $(event.target).data('url');
  if(event.ctrlKey || e.metaKey)
    window.open(url,'_blank');
  else
    window.location = url;
}
