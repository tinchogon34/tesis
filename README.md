# Procesamiento Distribuido


Trabajo Final para la carrera Ingeniera en Informatica en la [Universidad de
Mendoza] [1] de:

+ López, Gabriel Marcos <gabriel.lopez@trustit.solutions>

+ Gonzalez, Martin Gerónimo <tinchogon34@gmail.com>

## Breve descripción del tema.

Procesamiento Distribuido web usando Javascript.
Nuestra tesis propone una solución económica a las grandes cantidades de
procesamiento. La persona o entidad que desea resolver este procesamiento
se lo deneminará genericamente como **"invesitigador"**.

Se utilizará el patrón "MapReduce" y el investigador deberá proporcionar
tanto la función map y reduce. No tendremos ningún tipo de interferencia
en su códogo.

Alojaremos sus funciones, las datos necesarios y sus resultados en un
servidor web, que llamaremos "Servidor de Tareas", o simplemente T.

Abran muchos otros servidores web W que se encargaran de distribuir
el siguiente tag
```
#!html
<script type="text/javascript" src="T/proc.js" />
```
Nos valdremos de la recomendación de [Recursos Compartidos de Origenes
Cruzados (CORS)] [2] para poder brindar el script proc.js.

Nuestro script proc.js se encargara de pedir a nuestro servidor T
procesos que ejecutaran la funciona Map del Investigador en un Web Worker
en el cliente de W y nos traeran las resultados para luego realizar
la funcion Reduce.


### Instalación

+ Instalar *mongodb* en el OS

+ Instalar dependencias:

`npm install express.io underscore mongodb body-parser morgan compression serve-static sleep`


[1]: http://www.um.edu.ar/
[2]: http://en.wikipedia.org/wiki/Cross-origin_resource_sharing
