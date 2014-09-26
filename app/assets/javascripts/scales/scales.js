/* Based on source code from the Blog post by Mike Thomas at: http://atomicrobotdesign.com/blog/web-development/controlling-html-using-the-jquery-ui-slider-and-links/ */



(function($){
    var options = $("#options li");
    options.each(function(i){
        var left = 100 / (options.length - 1) * i;
        $(this).css("left", left + "%");
    });
    
    $("#slider").slider({
        min: 0, 
        max: options.length - 1, 
        range: "min",
        slide: function( event, ui ) {
            $(options.removeClass("selected")[ui.value]).addClass("selected");
            $("#zoom .selected").removeClass("selected");
            $("#zoom .panel:eq(" + ui.value + ")").addClass("selected");
        }
    });

    $("#options li").click(function(){
        $("#slider").slider( "value", $(this).index());
    });


}(window.jQuery));