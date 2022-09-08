$(document).ready(function () {

// Show debug toggles
if (location.hostname === "127.0.0.1") {
    $(".debug-hidden").show();
}

function updateCheckboxCounter(counter, countOf) {
    var countAll = 0;
    var countChecked = 0;
    countOf.querySelectorAll("input[type=checkbox]").forEach(function(element) {
        countAll += 1;
        countChecked += element.checked ? 1 : 0
    });
    counter.innerHTML = `${countChecked} / ${countAll}`;
    counter.style.display = countChecked == 0 ? "none" : "block";
}
function setupCheckboxCounter() {
    document.querySelectorAll('.checkboxcounter').forEach(function(counter) {
        const countOf = document.querySelector(counter.dataset.countCheckboxesOf);
        updateCheckboxCounter(counter, countOf);
        countOf.querySelectorAll("input[type=checkbox]").forEach(function(element) {
            element.addEventListener('change', (event) => {
                updateCheckboxCounter(counter, countOf);
            })
        });
    })
}

function previewData(data, downloadTime) {
    var yAxis = [];
    let codes = {0: "fair", 1: "mainly clear", 2: "partly cloudy", 3: "overcast", 45: "fog", 
        48: "depositing rime fog", 51: "light drizzle", 53: "moderate drizzle", 55: "dense drizzle", 
        56: "light freezing drizzle", 57: "dense freezing drizzle", 61: "slight rain", 63: "moderate rain", 
        65: "heavy rain", 66: "light freezing rain", 67: "heavy freezing rain", 71: "slight snow fall", 
        73: "moderate snow fall", 75: "heavy snow fall", 77: "snow grains", 80: "slight rain showers", 
        81: "moderate rain showers", 82: "heavy rain showers", 85: "slight snow showers", 86: "heavy snow showers",
        95: "slight to moderate thunderstorm", 96: "thunderstorm with slight hail", 99: "thunderstorm with heavy hail"
    };

    var series = [];
    ["hourly", "six_hourly", "three_hourly", "daily"].forEach(function (section, index) {
        if (!(section in data)) {
            return
        }
        Object.entries(data[section]||[]).forEach(function(k){
            if (k[0] == "time" || k[0] == "sunrise" || k[0] == "sunset") {
                return
            }
            let hourly_starttime = (data[section].time[0] + data.utc_offset_seconds) * 1000;
            let pointInterval = (data[section].time[1] - data[section].time[0]) * 1000;
            let unit = data[`${section}_units`][k[0]];
            var axisId = null;
            for (let i = 0; i < yAxis.length; i++) {
                if (yAxis[i].title.text == unit) {
                    axisId = i;
                }
            }
            if (axisId == null) {
                yAxis.push({title: {text: unit}});
                axisId = yAxis.length-1;
            }
            var ser = {
                name: k[0],
                data: k[1],
                yAxis: axisId,
                pointStart:hourly_starttime,
                pointInterval: pointInterval,
                tooltip: {
                    valueSuffix: " " + unit,
                }
            };
    
            if (k[0] == "weathercode") {
                ser.tooltip.pointFormatter = function () {
                    let condition = codes[this.y];
                    return "<span style=\"color:"+this.series.color+"\">\u25CF</span> "+this.series.name+": <b>"+condition+"</b> ("+this.y+" wmo)<br/>"
                }
            }

            series.push(ser);
        });
    });

    var plotBands = []
    if ('daily' in data && 'sunrise' in data.daily && 'sunset' in data.daily) {
        let rise = data.daily.sunrise
        let set = data.daily.sunset
        var plotBands = rise.map(function(r, i) {
            return {
                "color": "rgb(255, 255, 194)",
                "from": (r + data.utc_offset_seconds) * 1000,
                "to": (set[i] + data.utc_offset_seconds) * 1000
            };
        });
    }

    let latitude = data.latitude.toFixed(2);
    let longitude = data.longitude.toFixed(2);
    let title = `${latitude}°N ${longitude}°E`;
    
    if ("elevation" in data) {
        let elevation = data.elevation.toFixed(0);
        title = `${title} ${elevation}m above sea level`;
    }
    let generationtime_ms = data.generationtime_ms.toFixed(2);

    let utc_offset_sign = data.utc_offset_seconds < 0 ? "" : "+"

    let json =  {

        title: {
            text: title
        },
    
        subtitle: {
            text: `Generated in ${generationtime_ms}ms, downloaded in ${downloadTime.toFixed(0)}ms, time in GMT${utc_offset_sign}${data.utc_offset_seconds/3600}`
        },

        chart: {
            zoomType: 'x'
        },    
    
        yAxis: yAxis,
    
        xAxis: {
            type: 'datetime',
            plotLines: [{
                value: Date.now() + data.utc_offset_seconds * 1000,
                color: 'red',
                width: 2
            }],
            plotBands: plotBands
        },
    
        legend: {
            layout: 'vertical',
            align: 'right',
            verticalAlign: 'middle'
        },
    
        plotOptions: {
            series: {
                label: {
                    connectorAllowed: false
                },
            }
        },
    
        series: series,
    
        responsive: {
            rules: [{
                condition: {
                    maxWidth: 800
                },
                chartOptions: {
                    legend: {
                        layout: 'horizontal',
                        align: 'center',
                        verticalAlign: 'bottom'
                    }
                }
            }]
        },
        tooltip: {
            shared: true,
        }
    }
    //console.log(JSON.stringify(json, null, 2));
    if (document.getElementById('container')) {
        Highcharts.chart('container', json);
    }
    if (document.getElementById('containerStockcharts')) {
        Highcharts.stockChart('containerStockcharts', json);
    }
}

$("#detect_gps").click(function(e){
    e.preventDefault();
    if(!'geolocation' in navigator) {
        alert("GPS not available");
        return;
     }
     navigator.geolocation.getCurrentPosition((position) => {
         $('#latitude').val(position.coords.latitude.toFixed(2));
         $('#longitude').val(position.coords.longitude.toFixed(2));
         $('#api_form').submit();
     }, (error) => {
         alert("An error occurred: " + error.message);
     });
});

$("#select_city").change(function(e){
    let selected = $(this).find(':selected');
    $('#latitude').val(selected.data('latitude'));
    $('#longitude').val(selected.data('longitude'));
    $('#api_form').submit();
});

var frm = $('#api_form');
var frmInitialParameter = frm.serialize();
frm.submit(function(e){
    e.preventDefault();

    var t0 = performance.now()
    var previous = "";
    var first = true;
    var params = "";

    frm.serializeArray().forEach((v) => {
        let defaultValue = frm.find('[name="'+v.name+'"]').data("default");
        if (v.value == defaultValue) {
            return;
        }
        if (previous == v.name) {
            params += "," + encodeURIComponent(v.value);
        } else {
            if (!first) {
                params += "&"
            }
            params += v.name + "=" + encodeURIComponent(v.value);
        }
        previous = v.name;
        first = false;
    });

    // Set action URL to localhost for debugging
    var action = frm.prop('action');
    if ($('#localhost').is(":checked")) {
        const urlparts = new URL(action);
        action = `http://127.0.0.1:8080${urlparts.pathname}`;
    }
    let url = action + "?" + params;

    if ("originalEvent" in e && e.originalEvent.submitter.name == "format") {
        window.location.href = `${url}&format=${e.originalEvent.submitter.value}`;
        return;
    }

    if (frmInitialParameter != frm.serialize()) {
        // Only set location hash for non default configurations
        window.location.hash = params;
    }

    $('#api_url').val(url);
    $('#api_url_link').prop("href", url);
    
    $.ajax({
        type: frm.prop('method'),
        url: url + "&timeformat=unixtime",
        dataType: 'json',
        success: function (data) {
            var downloadTime = performance.now() - t0
            //console.log(data);
            previewData(data, downloadTime);
        },
        error: function (data) {
            console.warn('An error occurred.');
            console.warn(data);
            alert("API error: "+data.responseJSON.reason);
        },
    });
  });

  // restore form state from url
  let urlparams = window.location.hash.substring(1).split("&");
  if (urlparams.length > 2) {
    // uncheck all checkboxes
    frm.find("input[type=checkbox]").each(function() {
        this.checked = false;
    });
    for (const element of urlparams) {
        let parts = element.split("=");
        let key = parts[0];
        let value = decodeURIComponent(parts[1]);
        frm.find("select[name='" + key + "']").val(value);
        frm.find("input[name='" + key + "'][type=text]").val(value);
        frm.find("input[name='" + key + "'][type=number]").val(value);
        frm.find("input[name='" + key + "'][type=checkbox]").each(function() {
            this.checked = value.split(",").includes(this.value);
        });
    }
  }

  frm.submit();
  setupCheckboxCounter();
});
