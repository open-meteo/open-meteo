//
//  S3DataIndex.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 06.08.2026.
//
import Vapor

fileprivate let indexHtml = """
    <!DOCTYPE html>

    <!--
    Copyright 2014-2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.

    Licensed under the Apache License, Version 2.0 (the "License").

    You may not use this file except in compliance with the License. A copy
    of the License is located at

    https://aws.amazon.com/apache2.0/

    or in the "license" file accompanying this file. This file is distributed
    on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
    either express or implied. See the License for the specific language governing
    permissions and limitations under the License.
    -->

    <html lang="en">

    <head>
        <title>OpenMeteo Data Explorer</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="shortcut icon" href="https://aws.amazon.com/favicon.ico">
        <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/3.4.0/css/bootstrap.min.css" integrity="sha384-PmY9l28YgO4JwMKbTvgaS7XNZJ30MK9FAZjjzXtlqyZCqBY6X6bXIkM++IkyinN+" crossorigin="anonymous">
        <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/3.4.0/css/bootstrap-theme.min.css" integrity="sha384-jzngWsPS6op3fgRCDTESqrEJwRKck+CILhJVO5VvaAZCq8JYf8HsR/HPpBOOPZfR" crossorigin="anonymous">
        <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.12.0/css/all.css">
        <link rel="stylesheet" href="https://cdn.datatables.net/1.10.19/css/dataTables.bootstrap.min.css">
        <style type="text/css">
            #wrapper {
                padding-left: 0;
            }

            #page-wrapper {
                width: 100%;
                padding: 5px 15px;
            }

            #tb-s3objects {
                width: 100% !Important;
            }

            a {
                color: #00B7FF;
            }

            body {
                font: 14px "Lucida Grande", Helvetica, Arial, sans-serif;
            }

            td {
                font: 12px "Lucida Grande", Helvetica, Arial, sans-serif;
            }

            .title {
                padding: 6px 12px;
            }

            .breadcrumb {
                margin-bottom: 0;
            }

            #navbuttons .btn {
                padding: 3px 6px;
            }
        </style>
    </head>

    <!-- DEBUG: Enable this for red outline on all elements -->
    <!-- <style media="screen" type="text/css"> * { outline: 1px red solid; } </style> -->

    <body>
        <div id="page-wrapper">
            <div class="row">
                <div class="col-lg-12">
                    <div class="panel panel-primary">

                        <!-- Panel including title, breadcrumbs, and controls -->
                        <div class="panel-heading clearfix">
                            <!-- Title and breadcrumbs -->
                            <div class="btn-group pull-left">
                                <!-- App title -->
                                <div class="title pull-left">
                                    OpenMeteo Data Explorer&nbsp;
                                </div>
                                <!-- Bucket breadcrumbs -->
                                <div class="pull-right">
                                    <ul id="breadcrumb" class="breadcrumb pull-right">
                                        <li class="active">
                                            <a href="#">&lt;bucket&gt;</a>
                                        </li>
                                    </ul>
                                </div>
                            </div>
                            <!-- Controls -->
                            <div id="navbuttons" class="pull-right">
                                <div>
                                    <!-- Hide folders checkbox -->
                                    <div class="btn-group">
                                        <label class="btn">
                                            <input type="checkbox" id="hidefolders">&nbsp;Hide folders?
                                        </label>
                                    </div>
                                    <!-- Folder/Bucket radio group -->
                                    <div class="btn-group" data-toggle="buttons">
                                        <label class="btn btn-primary active" title="View all objects in folder">
                                            <i class="fa fa-angle-double-up"></i>
                                            <input type="radio" name="optionsdepth" value="folder" id="optionfolder" checked>&nbsp;Folder
                                        </label>
                                        <label class="btn btn-primary" title="View all objects in bucket">
                                            <i class="fa fa-angle-double-down"></i>
                                            <input type="radio" name="optionsdepth" value="bucket" id="optionbucket">&nbsp;Bucket
                                        </label>
                                    </div>
                                    <!-- Dual purpose: progress spinner and refresh button, plus object count -->
                                    <div class="btn-group" id="refresh">
                                        <span id="bucket-loader" style="cursor: pointer;" class="btn fa fa-refresh fa-2x pull-left" title="Refresh"></span>
                                        <span id="badgecount" class="badge pull-right" title="Object count">42</span>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Panel including S3 object table -->
                        <div class="panel-body">
                            <table class="table table-bordered table-hover table-striped" id="tb-s3objects">
                                <thead>
                                    <tr>
                                        <th>Object</th>
                                        <th>Folder</th>
                                        <th>Last Modified</th>
                                        <th>Timestamp</th>
                                        <th>Size</th>
                                    </tr>
                                </thead>
                                <tbody id="tbody-s3objects"></tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </body>

    </html>

    <script src="https://code.jquery.com/jquery-3.4.1.min.js"></script>
    <script src="https://stackpath.bootstrapcdn.com/bootstrap/3.4.0/js/bootstrap.min.js" integrity="sha384-vhJnz1OVIdLktyixHY4Uk3OHEwdQqPppqYR8+5mjsauETgLOcEynD9oPHhhz18Nw" crossorigin="anonymous"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/bootbox.js/4.4.0/bootbox.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.22.0/moment.min.js"></script>
    <script src="https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.10.19/js/dataTables.bootstrap.min.js"></script>

    <script type="text/javascript">
        var HIDE_INDEX = true;
        var s3exp_config = {
            Bucket: 'openmeteo',
            Prefix: '',
            Delimiter: '/'
        };
        var s3exp_lister = null;
        var s3exp_columns = {
            key: 1,
            folder: 2,
            date: 3,
            size: 4
        };

        // Initialize moment library (for time formatting utilities)
        moment().format();

        function bytesToSize(bytes) {
            var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
            if (bytes === 0) return '0 Bytes';
            var ii = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
            return Math.round(bytes / Math.pow(1024, ii), 2) + ' ' + sizes[ii];
        }

        // Custom startsWith function for String prototype
        if (typeof String.prototype.startsWith != 'function') {
            String.prototype.startsWith = function(str) {
                return this.indexOf(str) == 0;
            };
        }

        // Custom endsWith function for String prototype
        if (typeof String.prototype.endsWith != 'function') {
            String.prototype.endsWith = function(str) {
                return this.slice(-str.length) == str;
            };
        }

        function object2hrefvirt(bucket, key) {
            var enckey = key.split('/').map(function(x) { return encodeURIComponent(x); }).join('/');
            return document.location.origin + '/' + enckey;
        }

        function object2hrefpath(bucket, key) {
            var enckey = key.split('/').map(function(x) { return encodeURIComponent(x); }).join('/');
            return document.location.origin + '/' + enckey;
        }

        function htmlEscape(str) {
            return str
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;')
                .replace(/\\//g, '&#x2F;')
                .replace(/`/g, '&#x60;')
                .replace(/=/g, '&#x3D;');
        }

        function isthisdocument(bucket, key) {
            return key === "index.html";
        }

        function isfolder(path) {
            return path.endsWith('/');
        }

        // Convert cars/vw/golf.png to golf.png
        function fullpath2filename(path) {
            return htmlEscape(path.replace(/^.*[\\\\/]/, ''));
        }

        // Convert cars/vw/golf.png to cars/vw
        function fullpath2pathname(path) {
            return htmlEscape(path.substring(0, path.lastIndexOf('/')));
        }

        // Convert cars/vw/ to vw/
        function prefix2folder(prefix) {
            var parts = prefix.split('/');
            return htmlEscape(parts[parts.length - 2] + '/');
        }

        // Remove hash from document URL
        function removeHash() {
            history.pushState("", document.title, window.location.pathname + window.location.search);
        }

        function currentHashPrefix() {
            var hash = window.location.hash || '';
            if (!hash || hash.length <= 1) {
                return '';
            }
            return hash.substring(1);
        }

        // We are going to generate bucket/folder breadcrumbs. The resulting HTML will
        // look something like this:
        //
        // <li>Home</li>
        // <li>Library</li>
        // <li class="active">Samples</li>
        //
        // Note: this code is a little complex right now so it would be good to find
        // a simpler way to create the breadcrumbs.
        function folder2breadcrumbs(data) {
            console.log('Bucket: ' + data.params.Bucket);
            console.log('Prefix: ' + data.params.Prefix);

            if (data.params.Prefix && data.params.Prefix.length > 0) {
                console.log('Set hash: ' + data.params.Prefix);
                window.location.hash = data.params.Prefix;
            } else {
                console.log('Remove hash');
                removeHash();
            }

            // The parts array will contain the bucket name followed by all the
            // segments of the prefix, exploded out as separate strings.
            var parts = [data.params.Bucket];

            if (data.params.Prefix) {
                parts.push.apply(parts,
                    data.params.Prefix.endsWith('/') ?
                    data.params.Prefix.slice(0, -1).split('/') :
                    data.params.Prefix.split('/'));
            }

            console.log('Parts: ' + parts + ' (length=' + parts.length + ')');

            // Empty the current breadcrumb list
            $('#breadcrumb li').remove();

            // Now build the new breadcrumb list
            var buildprefix = '';
            $.each(parts, function(ii, part) {
                var ipart;

                // Add the bucket (the bucket is always first)
                if (ii === 0) {
                    var a1 = $('<a>').attr('href', '#').text(part);
                    ipart = $('<li>').append(a1);
                    a1.click(function(e) {
                        e.preventDefault();
                        console.log('Breadcrumb click bucket: ' + data.params.Bucket);
                        s3exp_config = {
                            Bucket: data.params.Bucket,
                            Prefix: '',
                            Delimiter: data.params.Delimiter
                        };
                        (s3exp_lister = s3list(s3exp_config, s3draw)).go();
                    });
                    // Else add the folders within the bucket
                } else {
                    buildprefix += part + '/';

                    if (ii == parts.length - 1) {
                        ipart = $('<li>').addClass('active').text(part);
                    } else {
                        var a2 = $('<a>').attr('href', '#').append(part);
                        ipart = $('<li>').append(a2);

                        // Closure needed to enclose the saved S3 prefix
                        (function() {
                            var saveprefix = buildprefix;
                            // console.log('Part: ' + part + ' has buildprefix: ' + saveprefix);
                            a2.click(function(e) {
                                e.preventDefault();
                                console.log('Breadcrumb click object prefix: ' + saveprefix);
                                s3exp_config = {
                                    Bucket: data.params.Bucket,
                                    Prefix: saveprefix,
                                    Delimiter: data.params.Delimiter
                                };
                                (s3exp_lister = s3list(s3exp_config, s3draw)).go();
                            });
                        })();
                    }
                }
                $('#breadcrumb').append(ipart);
            });
        }

        function s3draw(data, complete) {
            $('li.li-bucket').remove();
            folder2breadcrumbs(data);

            // Add each part of current path (S3 bucket plus folder hierarchy) into the breadcrumbs
            $.each(data.CommonPrefixes, function(i, prefix) {
                $('#tb-s3objects').DataTable().rows.add([{
                    Key: prefix.Prefix
                }]);
            });

            // Add S3 objects to DataTable
            $('#tb-s3objects').DataTable().rows.add(data.Contents).draw();
        }

        function s3list(config, completecb) {
            console.log('s3list config: ' + JSON.stringify(config));
            var params = {
                Bucket: config.Bucket,
                Prefix: config.Prefix,
                Delimiter: config.Delimiter
            };

            function localListObjects(params, callback) {
                function xmlSections(xml, tag) {
                    var sections = [];
                    var open = '<' + tag + '>';
                    var close = '</' + tag + '>';
                    var pos = 0;
                    while (true) {
                        var start = xml.indexOf(open, pos);
                        if (start === -1) break;
                        var contentStart = start + open.length;
                        var end = xml.indexOf(close, contentStart);
                        if (end === -1) break;
                        sections.push(xml.substring(contentStart, end));
                        pos = end + close.length;
                    }
                    return sections;
                }

                function xmlFirst(xml, tag) {
                    var open = '<' + tag + '>';
                    var close = '</' + tag + '>';
                    var start = xml.indexOf(open);
                    if (start === -1) return null;
                    var contentStart = start + open.length;
                    var end = xml.indexOf(close, contentStart);
                    if (end === -1) return null;
                    return xml.substring(contentStart, end);
                }

                var query = {
                    'list-type': 2,
                    'delimiter': params.Delimiter || '/',
                    'prefix': params.Prefix || ''
                };
                if (params.ContinuationToken) {
                    query['continuation-token'] = params.ContinuationToken;
                }

                $.ajax({
                    url: '/',
                    method: 'GET',
                    data: query,
                    success: function(xmlText) {
                        try {
                            var xmlString = '';
                            if (typeof xmlText === 'string') {
                                xmlString = xmlText;
                            } else if (xmlText && xmlText.documentElement) {
                                xmlString = new XMLSerializer().serializeToString(xmlText);
                            } else {
                                xmlString = String(xmlText || '');
                            }

                            var contents = xmlSections(xmlString, 'Contents').map(function(section) {
                                return {
                                    Key: xmlFirst(section, 'Key') || '',
                                    LastModified: xmlFirst(section, 'LastModified') || '',
                                    Size: parseInt(xmlFirst(section, 'Size') || '0', 10)
                                };
                            }).filter(function(item) {
                                return item.Key.length > 0;
                            });

                            var commonPrefixes = xmlSections(xmlString, 'CommonPrefixes').map(function(section) {
                                var prefix = xmlFirst(section, 'Prefix') || '';
                                return { Prefix: prefix };
                            }).filter(function(item) {
                                return item.Prefix.length > 0;
                            });

                            var isTruncatedText = (xmlFirst(xmlString, 'IsTruncated') || '').toLowerCase();
                            var nextToken = xmlFirst(xmlString, 'NextContinuationToken');

                            callback(null, {
                                Contents: contents,
                                CommonPrefixes: commonPrefixes,
                                IsTruncated: isTruncatedText === 'true',
                                NextContinuationToken: nextToken || undefined
                            });
                        } catch (e) {
                            callback(e);
                        }
                    },
                    error: function(xhr, status, error) {
                        callback(error || status || 'Local list API failed');
                    }
                });
            }

            var scope = {
                Contents: [],
                CommonPrefixes: [],
                params: params,
                stop: false,
                completecb: completecb
            };

            return {
                // This is the callback that the S3 API makes when an S3 listObjectsV2
                // request completes (successfully or in error). Note that a single call
                // to listObjectsV2 may not be enough to get all objects so we need to
                // check if the returned data is truncated and, if so, make additional
                // requests with a 'next marker' until we have all the objects.
                cb: function(err, data) {
                    if (err) {
                        console.log('Error: ' + JSON.stringify(err));
                        console.log('Error: ' + err.stack);
                        scope.stop = true;
                        $('#bucket-loader').removeClass('fa-spin');
                        bootbox.alert("Error accessing S3 bucket " + scope.params.Bucket + ". Error: " + err);
                    } else {
                        // console.log('Data: ' + JSON.stringify(data));
                        console.log("Options: " + $("input[name='optionsdepth']:checked").val());

                        // Store marker before filtering data
                        if (data.IsTruncated) {
                            if (data.NextContinuationToken) {
                                scope.params.ContinuationToken = data.NextContinuationToken;
                            }
                        }

                        // Filter the folders out of the listed S3 objects
                        // (could probably be done more efficiently)
                        console.log("Filter: remove folders");
                        data.Contents = data.Contents.filter(function(el) {
                            return el.Key !== scope.params.Prefix;
                        });

                        // Optionally, filter the root index.html out of the listed S3 objects
                        if (HIDE_INDEX) {
                            console.log("Filter: remove index.html");
                            data.Contents = data.Contents.filter(function(el) {
                                return el.Key !== "index.html";
                            });
                        }

                        // Accumulate the S3 objects and common prefixes
                        scope.Contents.push.apply(scope.Contents, data.Contents);
                        scope.CommonPrefixes.push.apply(scope.CommonPrefixes, data.CommonPrefixes);

                        // Update badge count to show number of objects read
                        $('#badgecount').text(scope.Contents.length + scope.CommonPrefixes.length);

                        if (scope.stop) {
                            console.log('Bucket ' + scope.params.Bucket + ' stopped');
                        } else if (data.IsTruncated) {
                            console.log('Bucket ' + scope.params.Bucket + ' truncated');
                            localListObjects(scope.params, scope.cb);
                        } else {
                            console.log('Bucket ' + scope.params.Bucket + ' has ' + scope.Contents.length + ' objects, including ' + scope.CommonPrefixes.length + ' prefixes');
                            delete scope.params.ContinuationToken;
                            if (scope.completecb) {
                                scope.completecb(scope, true);
                            }
                            $('#bucket-loader').removeClass('fa-spin');
                        }
                    }
                },

                // Start the spinner, clear the table, make an S3 listObjectsV2 request
                go: function() {
                    scope.cb = this.cb;
                    $('#bucket-loader').addClass('fa-spin');
                    $('#tb-s3objects').DataTable().clear();
                    localListObjects(scope.params, this.cb);
                },

                stop: function() {
                    scope.stop = true;
                    delete scope.params.ContinuationToken;
                    if (scope.completecb) {
                        scope.completecb(scope, false);
                    }
                    $('#bucket-loader').removeClass('fa-spin');
                }
            };
        }

        function resetDepth() {
            $('#tb-s3objects').DataTable().column(1).visible(false);
            $('input[name="optionsdepth"]').val(['folder']);
            $('input[name="optionsdepth"][value="bucket"]').parent().removeClass('active');
            $('input[name="optionsdepth"][value="folder"]').parent().addClass('active');
        }

        $(document).ready(function() {
            console.log('ready');

            var suppressHashReload = false;

            function applyPrefixFromHash(reload) {
                var prefix = currentHashPrefix();
                var existingPrefix = s3exp_config.Prefix || '';
                if (prefix === existingPrefix) {
                    return;
                }

                if (prefix) {
                    s3exp_config.Prefix = prefix;
                } else {
                    delete s3exp_config.Prefix;
                }

                if (reload) {
                    delete s3exp_config.ContinuationToken;
                    (s3exp_lister = s3list(s3exp_config, s3draw)).go();
                }
            }

            $(window).on('hashchange', function() {
                if (suppressHashReload) {
                    return;
                }
                applyPrefixFromHash(true);
            });


            // Click handler for refresh button (to invoke manual refresh)
            $('#bucket-loader').click(function(e) {
                if ($('#bucket-loader').hasClass('fa-spin')) {
                    // To do: We need to stop the S3 list that's going on
                    // bootbox.alert("Stop is not yet supported.");
                    s3exp_lister.stop();
                } else {
                    delete s3exp_config.ContinuationToken;
                    (s3exp_lister = s3list(s3exp_config, s3draw)).go();
                }
            });

            // Bucket chooser is unused in local mode.
            $('#bucket-chooser').click(function(e) {
                e.preventDefault();
            });

            $('#hidefolders').click(function(e) {
                $('#tb-s3objects').DataTable().draw();
            });

            // Folder/Bucket radio button handler
            $("input:radio[name='optionsdepth']").change(function() {
                console.log("Folder/Bucket option change to " + $(this).val());
                console.log("Change options: " + $("input[name='optionsdepth']:checked").val());

                // If user selected deep then we do need to do a full list
                if ($(this).val() == 'bucket') {
                    console.log("Switch to bucket");
                    var choice = $(this).val();
                    $('#tb-s3objects').DataTable().column(1).visible(choice === 'bucket');
                    delete s3exp_config.ContinuationToken;
                    delete s3exp_config.Prefix;
                    s3exp_config.Delimiter = '';
                    (s3exp_lister = s3list(s3exp_config, s3draw)).go();
                    // Else user selected folder then can do a delimiter list
                } else {
                    console.log("Switch to folder");
                    $('#tb-s3objects').DataTable().column(1).visible(false);
                    delete s3exp_config.ContinuationToken;
                    delete s3exp_config.Prefix;
                    s3exp_config.Delimiter = '/';
                    (s3exp_lister = s3list(s3exp_config, s3draw)).go();
                }
            });

            function renderObject(data, type, full) {
                if (isthisdocument(s3exp_config.Bucket, data)) {
                    console.log("is this document: " + data);
                    return fullpath2filename(data);
                } else if (isfolder(data)) {
                    console.log("is folder: " + data);
                    return '<a data-s3="folder" data-prefix="' + htmlEscape(data) + '" href="' + object2hrefvirt(s3exp_config.Bucket, data) + '">' + prefix2folder(data) + '</a>';
                } else {
                    console.log("not folder/this document: " + data);
                    return '<a data-s3="object" href="' + object2hrefvirt(s3exp_config.Bucket, data) + '"download="' + fullpath2filename(data) + '">' + fullpath2filename(data) + '</a>';
                }
            }

            function renderFolder(data, type, full) {
                return isfolder(data) ? "" : fullpath2pathname(data);
            }

            // Initial DataTable settings
            $('#tb-s3objects').DataTable({
                iDisplayLength: 50,
                order: [
                    [1, 'asc'],
                    [0, 'asc']
                ],
                aoColumnDefs: [{
                    "aTargets": [0],
                    "mData": "Key",
                    "mRender": function(data, type, full) {
                        return (type == 'display') ? renderObject(data, type, full) : data;
                    },
                    "sType": "key"
                }, {
                    "aTargets": [1],
                    "mData": "Key",
                    "mRender": function(data, type, full) {
                        return renderFolder(data, type, full);
                    }
                }, {
                    "aTargets": [2],
                    "mData": "LastModified",
                    "mRender": function(data, type, full) {
                        return data ? moment(data).fromNow() : "";
                    }
                }, {
                    "aTargets": [3],
                    "mData": "LastModified",
                    "mRender": function(data, type, full) {
                        return data ? moment(data).local().format('YYYY-MM-DD HH:mm:ss') : "";
                    }
                }, {
                    "aTargets": [4],
                    "mData": function(source, type, val) {
                        return source.Size ? ((type == 'display') ? bytesToSize(source.Size) : source.Size) : "";
                    }
                }, ]
            });

            $('#tb-s3objects').DataTable().column(s3exp_columns.key).visible(false);
            console.log("jQuery version=" + $.fn.jquery);

            // Custom sort for the Key column so that folders appear before objects
            $.fn.dataTableExt.oSort['key-asc'] = function(a, b) {
                var x = (isfolder(a) ? "0-" + a : "1-" + a).toLowerCase();
                var y = (isfolder(b) ? "0-" + b : "1-" + b).toLowerCase();
                return ((x < y) ? -1 : ((x > y) ? 1 : 0));
            };

            $.fn.dataTableExt.oSort['key-desc'] = function(a, b) {
                var x = (isfolder(a) ? "1-" + a : "0-" + a).toLowerCase();
                var y = (isfolder(b) ? "1-" + b : "0-" + b).toLowerCase();
                return ((x < y) ? 1 : ((x > y) ? -1 : 0));
            };

            // Allow user to hide folders
            $.fn.dataTableExt.afnFiltering.push(function(oSettings, aData, iDataIndex) {
                console.log("hide folders");
                return $('#hidefolders').is(':checked') ? !isfolder(aData[0]) : true;
            });

            // Delegated event handler for S3 object/folder clicks. This is delegated
            // because the object/folder rows are added dynamically and we do not want
            // to have to assign click handlers to each and every row.
            $('#tb-s3objects').on('click', 'a', function(event) {
                event.preventDefault();
                var target = event.target;
                console.log("target href=" + target.href);
                console.log("target dataset=" + JSON.stringify(target.dataset));

                // If the user has clicked on a folder then navigate into that folder
                if (target.dataset.s3 === "folder") {
                    resetDepth();
                    delete s3exp_config.ContinuationToken;
                    s3exp_config.Prefix = target.dataset.prefix;
                    s3exp_config.Delimiter = $("input[name='optionsdepth']:checked").val() == "folder" ? "/" : "";
                    (s3exp_lister = s3list(s3exp_config, s3draw)).go();

                    // Keep URL hash in sync for deep links and browser history.
                    var targetHash = '#' + target.dataset.prefix;
                    if (window.location.hash !== targetHash) {
                        suppressHashReload = true;
                        window.location.hash = target.dataset.prefix;
                        setTimeout(function() {
                            suppressHashReload = false;
                        }, 0);
                    }
                    // Else user has clicked on an object so download it in new window/tab
                } else {
                    window.open(target.href, '_blank');
                }
                return false;
            });

            applyPrefixFromHash(false);
            (s3exp_lister = s3list(s3exp_config, s3draw)).go();
        });
    </script>
    """

extension S3DataController {
    func index(_ req: Request) async throws -> Response {
        OmMetrics.requestsS3ApiTotal.add(1, ordering: .relaxed)
        guard OmMetrics.requestsRunning.load(ordering: .relaxed) <= RateLimiter.concurrencyLimitTotal else {
            OmMetrics.requestsServiceOverloadedTotal.add(1, ordering: .relaxed)
            throw RateLimitError.serviceOverloaded
        }
        return try await req.withFreeApiRateLimiter { _ in
            return (1, Response(status: .ok, body: .init(stringLiteral: indexHtml)))
        }
    }
}
