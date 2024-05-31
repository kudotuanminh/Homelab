var Service = require('node-windows').Service;
var svc = new Service({
 name:'demergi-dpi',
 description: 'A proxy server that helps to bypass the DPI systems implemented by various ISPs.',
 script: 'C:\\Program Files\\nodejs\\node_modules\\demergi\\bin\\demergi.js'
});

svc.on('install',function(){
 svc.start();
});

svc.install();