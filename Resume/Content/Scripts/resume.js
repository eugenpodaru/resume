﻿$(window).scroll(function () {
    // jQuery to collapse the navbar on scroll
    if ($(".navbar-fixed-top").offset().top > $(".resume-header hr").offset().top) {
        $(".navbar-fixed-top").addClass("navbar-fixed-top-shown");
    } else {
        $(".navbar-fixed-top").removeClass("navbar-fixed-top-shown");
    }
});

// jQuery for page scrolling feature - requires jQuery Easing plugin
$(function () {
    $("a.page-scroll").bind("click", function (event) {
        var $anchor = $(this);
        $("html, body").stop().animate({
            scrollTop: $($anchor.attr("href")).offset().top
        }, 1500, "easeInOutExpo");
        event.preventDefault();
    });
});

// Closes the Responsive Menu on Menu Item Click
$(".navbar-brand, .navbar-collapse ul li a").click(function () {
    if ($(".navbar-collapse").is(":visible"))
        $(".navbar-toggle").click();
});