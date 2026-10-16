(function(){
"use strict";
const T_SCRIPT=performance.now(); // when the script starts running (after the download and three.js): __stats.load
const $=s=>document.querySelector(s);
const loadMsg=t=>{$('#load-msg').textContent=t};
if(!window.THREE){$('#err').hidden=false;$('#err').textContent='No se pudo cargar la librería 3D (three.js). Revise su conexión y recargue la página.';return;}
const T=THREE;

