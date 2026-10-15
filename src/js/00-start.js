(function(){
"use strict";
const $=s=>document.querySelector(s);
const loadMsg=t=>{$('#load-msg').textContent=t};
if(!window.THREE){$('#err').hidden=false;$('#err').textContent='No se pudo cargar la librería 3D (three.js). Revise su conexión y recargue la página.';return;}
const T=THREE;

