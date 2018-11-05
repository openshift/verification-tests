(function($) {
  /*
   * forked from https://github.com/mattheworiordan/jquery.simulate.drag-sortable.js
   * options are:
   * - move: move item up (positive) or down (negative) by Integer amount
   * - handle: selector for the draggable handle element (optional)
   * - listItem: selector to limit which sibling items can be used for reordering
   * - tolerance: (optional) number of pixels to overlap by instead of the default 50% of the element height
   *
   */
  $.fn.simulateDragSortable = function(options) {
    // build main options before element iteration
    var opts = $.extend({}, $.fn.simulateDragSortable.defaults, options);

    applyDrag = function(options) {
      // allow for a drag handle if item is not draggable
      var that = this,
          options = options || opts, // default to plugin opts unless options explicitly provided
          handle = options.handle ? $(this).find(options.handle)[0] : $(this)[0],
          listItem = options.listItem,
          sibling = $(this),
          moveCounter = Math.floor(options.move),
          moveDirection = (moveCounter > 0) ? 'down' : 'up',
          moveVerticalAmount = 0,
          tolerance = !isNaN(parseInt(options.tolerance, 10)) ? Number(options.tolerance) : 0,
          center = findCenter(handle),
          x = Math.floor(center.x),
          y = Math.floor(center.y),
          mouseUpAfter = (opts.debug ? 2500 : 10);

      if (moveCounter === 0) {
        if (console && console.log) { console.log('simulate.drag-sortable.js WARNING: Drag with move set to zero has no effect'); }
        return;
      } else {
        while (moveCounter !== 0) {
          if (moveDirection === 'down') {
            console.log(listItem)
            if (sibling.next(listItem).length) {
              sibling = sibling.next(listItem);
              console.log(sibling)
              moveVerticalAmount += sibling.outerHeight();
            }
            moveCounter -= 1;
          } else {
            if (sibling.prev(listItem).length) {
              sibling = sibling.prev(listItem);
              moveVerticalAmount -= sibling.outerHeight();
            }
            moveCounter += 1;
          }
        }
      }

      dispatchEvent(handle, 'mousedown', createEvent('mousedown', handle, { clientX: x, clientY: y }));
      // simulate drag start
      dispatchEvent(document, 'mousemove', createEvent('mousemove', document, { clientX: x+1, clientY: y+1 }));

      if (moveDirection === "up") {
        moveVerticalAmount -= tolerance;
      } else {
        moveVerticalAmount += tolerance;
      }

      if (sibling[0] !== $(this)[0]) {
        slideUpTo(x, y, moveVerticalAmount);
      } else {
        if (window.console) {
          console.log('simulate.drag-sortable.js WARNING: Could not move as at top or bottom already');
        }
      }

      setTimeout(function() {
        dispatchEvent(document, 'mousemove', createEvent('mousemove', document, { clientX: x, clientY: y + moveVerticalAmount }));
      }, 5);
      setTimeout(function() {
        dispatchEvent(handle, 'mouseup', createEvent('mouseup', handle, { clientX: x, clientY: y + moveVerticalAmount }));
      }, mouseUpAfter);
    };

    // iterate and move each matched element
    return this.each(applyDrag);
  };

  // fire mouse events, go half way, then the next half, so small mouse movements near target and big at the start
  function slideUpTo(x, y, targetOffset) {
    // var offset;

    // smooth half-way moving
    // for (offset = 0; Math.abs(offset) + 1 < Math.abs(targetOffset); offset += ((targetOffset - offset)/2) ) {
    //   dispatchEvent(document, 'mousemove', createEvent('mousemove', document, { clientX: x, clientY: y + Math.ceil(offset) }));
    // }
    dispatchEvent(document, 'mousemove', createEvent('mousemove', document, { clientX: x, clientY: y + targetOffset }));
  }

  function createEvent(type, target, options) {
    var evt;
    var e = $.extend({
      target: target,
      preventDefault: function() { },
      stopImmediatePropagation: function() { },
      stopPropagation: function() { },
      isPropagationStopped: function() { return true; },
      isImmediatePropagationStopped: function() { return true; },
      isDefaultPrevented: function() { return true; },
      bubbles: true,
      cancelable: (type != "mousemove"),
      view: window,
      detail: 0,
      screenX: 0,
      screenY: 0,
      clientX: 0,
      clientY: 0,
      ctrlKey: false,
      altKey: false,
      shiftKey: false,
      metaKey: false,
      button: 0,
      relatedTarget: undefined
    }, options || {});

    if ($.isFunction(document.createEvent)) {
      evt = document.createEvent("MouseEvents");
      evt.initMouseEvent(type, e.bubbles, e.cancelable, e.view, e.detail,
        e.screenX, e.screenY, e.clientX, e.clientY,
        e.ctrlKey, e.altKey, e.shiftKey, e.metaKey,
        e.button, e.relatedTarget || document.body.parentNode);
    } else if (document.createEventObject) {
      // IE or Edge (not tested)
      evt = document.createEventObject();
      $.extend(evt, e);
        evt.button = { 0:1, 1:4, 2:2 }[evt.button] || evt.button;
    }
    return evt;
  }

  function dispatchEvent(el, type, evt) {
    if (el.dispatchEvent) {
      el.dispatchEvent(evt);
    } else if (el.fireEvent) {
      el.fireEvent('on' + type, evt);
    }
    return evt;
  }

  function findCenter(el) {
    var elm = $(el),
        o = elm.offset();
    return {
      x: o.left + elm.outerWidth() / 2,
      y: o.top + elm.outerHeight() / 2
    };
  }

  $.fn.simulateDragSortable.defaults = {
    move: 0
  };
})(jQuery);
return true;
