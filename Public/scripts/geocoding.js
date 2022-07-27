$(document).ready(function () {
    var xhr;

    function previewData(data, downloadTime) {
        var table = $('<table class="table">');

        var tableHeader = $('<thead><tr><th></th><th>Name</th><th>Latitude</th><th>Longitude</th><th>Elevation</th><th>Population</th><th>Admin1</th><th>Admin2</th><th>Admin3</th><th>Admin4</th><th>Feature code</th></tr></thead>');
        var tableBody = $('<tbody>');
        
        table.append(tableHeader);
        table.append(tableBody);

        for (var i = 0, len = (data.results || []).length; i < len; i++) {
            let row = data.results[i];
            
            row = $('<tr><td class="p-1"><img height=32 src="https://assets.open-meteo.com/images/country-flags/' + row.country_code.toLowerCase() + '.svg" title="' + row.country + '"/></td><td>' + row.name + '</td><td>' + row.latitude + '</td><td>' + row.longitude + '</td><td>' + row.elevation + '</td><td>' + (row.population||'') + '</td><td>' + (row.admin1||'') + '</td><td>' + (row.admin2||'') + '</td><td>' + (row.admin3||'') + '</td><td>' + (row.admin4||'') + '</td><td>' + row.feature_code + '</td></tr>');
            tableBody.append(row);
        }

        $('#container').html(table);
    }
    
    var frm = $('#geocoding_form');
    $('#name').on("input", function() {
        frm.submit();
    });
    frm.on('change', function() {
        frm.submit()
    });
    frm.submit(function(e){
        e.preventDefault();
        if (xhr) {
            xhr.abort();
        }
    
        var t0 = performance.now()
        var url = frm.prop('action') + "?";
        var previous = "";
        var first = true;
    
        frm.serializeArray().forEach((v) => {
            let defaultValue = frm.find('[name="'+v.name+'"]').data("default");
            if (v.value == defaultValue) {
                return;
            }
            if (previous == v.name) {
                url += "," + encodeURIComponent(v.value);
            } else {
                if (!first) {
                    url += "&"
                }
                url += v.name + "=" + encodeURIComponent(v.value);
            }
            previous = v.name;
            first = false;
        });
    
        $('#api_url').val(url);
        $('#api_url_link').prop("href", url);
        
        xhr = $.ajax({
            type: frm.prop('method'),
            url: url + "&format=json",
            dataType: 'json',
            success: function (data) {
                var downloadTime = performance.now() - t0
                console.log('Submission was successful.');
                console.log(data);
                previewData(data, downloadTime);
            },
            error: function (data) {
                console.log('An error occurred.');
                console.log(data);
                alert("API error: "+data.responseJSON.reason);
            },
        });
      });
    
      frm.submit();
});
    