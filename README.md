# Citatec

Aplicación multiplataforma desarrollada como proyecto académico en equipo para facilitar la gestión de citas y trámites dentro del Instituto Tecnológico de Iguala.

## Mi participación

Participé en el desarrollo de la interfaz, integración de funcionalidades y pruebas del sistema.

## Funcionalidades principales

- Inicio de sesión con Firebase.
- Roles de administrador y usuario.
- Gestión de citas.
- Consulta de departamentos y trámites.
- Panel administrativo.
- Persistencia de datos con Cloud Firestore.

## Tecnologías utilizadas

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Git y GitHub

## Trabajo colaborativo

Este proyecto fue desarrollado en equipo como parte de una actividad académica.

# Citatec11 - Documentación para Desarrolladores

Este documento sirve como guía técnica para entender la estructura, funcionamiento y lógica detrás de la aplicación **Citatec**. Está diseñado para ayudar a nuevos programadores a familiarizarse rápidamente con el código.

## 🛠 Stack Tecnológico

- **Framework**: Flutter (Dart)
- **Backend & Base de Datos**: Firebase (Authentication, Cloud Firestore)
- **Gestión de Estado**: `setState` y `StreamBuilder` (Nativo)

---

## 📂 Estructura del Proyecto

El código fuente se encuentra en la carpeta `lib/`. Aquí está el desglose de los directorios clave:

- **`lib/main.dart`**: Punto de entrada de la aplicación.
  - Inicializa Firebase (`Firebase.initializeApp`).
  - Configura el tema (Claro/Oscuro).
  - Define la pantalla inicial (`LoginPage`).

- **`lib/pages/`**: Contiene las pantallas (vistas) de la aplicación.
- **`lib/services/`**: Contiene la lógica de negocio y comunicación con Firebase.
- **`lib/components/`**: Widgets reutilizables (Botones, Inputs, etc.).
- **`lib/theme/`**: Definiciones de estilos y colores (`claro.dart`, `oscuro.dart`).
- **`firebase_options.dart`**: Archivo de configuración generado automáticamente para conectar con el proyecto de Firebase.

---

## 🔐 Autenticación y Login

**Ubicación de archivos clave:**
- 📄 UI: `lib/pages/login_page.dart`
- ⚙️ Lógica: `lib/services/auth_service.dart`

### ¿Cómo funciona?
1. **Entrada de Datos**: El usuario ingresa su **Usuario/No. Control** y selecciona un **Dominio** (ej. `@gmail.com`, `@iguala.edu.mx`).
2. **Concatenación**: En `LoginPage`, se concatena el usuario con el dominio para formar el correo electrónico completo.
   ```dart
   String fullEmail = no + _selectedDomain;
   ```
3. **Validación**: Se llama a `AuthService.signInWithEmailAndPassword`.
4. **Roles**: Una vez autenticado, se consulta la colección `users` en Firestore para obtener el rol del usuario (`rol: 'admin'` o `'user'`).
   - Si es **admin** -> Redirige a `AdminPage`.
   - Si es **usuario** -> Redirige a `HomePage`.

---

## 📅 Gestión de Citas

**Ubicación de archivos clave:**
- 📄 UI: `lib/pages/cita_page.dart`
- ⚙️ Lógica: `lib/services/firestore_service.dart`

### Flujo de Creación (CitaPage)
Utiliza un widget `Stepper` de 4 pasos:
1. **Departamento**: Se obtienen dinámicamente de la colección `departamentos` en Firestore.
2. **Servicio (Trámite)**: Se carga la lista de trámites basada en el departamento seleccionado.
3. **Fecha**: `DatePicker` para seleccionar el día.
4. **Hora**: Selección de chips con horarios predefinidos.

### Guardado en Base de Datos
Al confirmar, se llama a `FirestoreService.createCita`, que guarda un documento en la colección `citas` con:
- `userId`: ID del usuario autenticado.
- `userName`: Correo/Nombre del usuario.
- `departamento`, `servicio`, `fecha`, `hora`.
- `estado`: Inicializado como `'Activa'`.

---

## 👮‍♂️ Panel de Administrador

**Ubicación de archivos clave:**
- 📄 UI: `lib/pages/Admin_page.dart` (Nota: en código puede aparecer como `admin_page.dart` o `Admin_page.dart`)

### Funcionalidades
1. **Ver Citas**: 
   - Tab "Citas".
   - `StreamBuilder` que escucha `FirestoreService.getAllCitas()`.
   - Muestra todas las citas ordenadas por fecha.
2. **Gestión de Departamentos y Trámites**:
   - Tab "Trámites".
   - Permite **Agregar/Eliminar Departamentos**.
   - Permite **Agregar/Eliminar Trámites** dentro de cada departamento.
   - Datos almacenados en la colección `departamentos`.

---

## 🗄 Modelo de Datos (Firestore)

### Colección `users`
Almacena roles de usuarios.
- Document ID: `uid` (del Auth)
- Campos: `{ rol: 'admin' | 'user' }`

### Colección `citas`
Almacena las citas agendadas.
- Campos: `userId`, `userName`, `departamento`, `servicio`, `fecha` (Timestamp), `hora`, `estado`, `created_at`.

### Colección `departamentos`
Configuración dinámica de la oferta de servicios.
- Document ID: Nombre del departamento (ej. `Escolares`).
- Campos:
  - `tramites`: Array de Strings `['Inscripción', 'Constancia', ...]`.

---

## 🚀 Cómo empezar para un nuevo desarrollador

1. **Clonar el repositorio**.
2. **Configurar Firebase**:
   - Asegúrate de tener el archivo `google-services.json` en `android/app/`.
   - Si no está, necesitarás configurar un proyecto en la consola de Firebase y generar uno nuevo.
3. **Instalar dependencias**:
   ```bash
   flutter pub get
   ```
4. **Correr la app**:
   ```bash
   flutter run
   ```
