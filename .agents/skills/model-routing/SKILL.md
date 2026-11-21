---
name: model-routing
description: >-
  Enrutamiento inteligente de modelos solo para el proyecto Roblox V8.
  Evaluar al recibir peticiones de desarrollo, depuración o investigación para
  equilibrar el uso de tokens y delegar tareas según su complejidad usando
  `invoke_subagent` con el parámetro `Model` adecuado (`flash_lite`, `flash`,
  `inherit` o `pro`).
---

# Enrutamiento de Modelos y Uso Equilibrado de Tokens (Proyecto Roblox V8)

Esta skill aplica únicamente dentro de este workspace (`d:\Roblox V8`). Su objetivo es evitar gastar tokens de modelos grandes en tareas simples y reservar los modelos más capaces para problemas realmente complejos.

## 1. Matriz de Selección de Modelo (`invoke_subagent`)

Antes de iniciar una tarea o delegarla a un subagente (`invoke_subagent`), clasifícala en uno de estos 4 niveles:

| Nivel / `Model` | Cuándo usarlo | Ejemplos en Roblox V8 |
| :--- | :--- | :--- |
| **`flash_lite`** | Tareas triviales, mecánicas o de lectura rápida. | Buscar texto en archivos, listar estructura del proyecto, cambiar valores en `Config.luau` (velocidad, colores, número de bots), explicar un bloque corto de código. |
| **`flash`** | Tareas estándar bien acotadas con bajo riesgo arquitectónico. | Crear elementos de UI/HUD simples, añadir un nuevo tipo de pickup siguiendo un patrón existente, ajustar parámetros visuales, ejecutar `rojo build` y reportar errores. |
| **`inherit`** | Conversación directa, coordinación y cambios medianos puntuales. | Responder dudas del usuario, hacer ediciones pequeñas en 1 archivo sin abrir un subagente extra, coordinar el plan por fases. |
| **`pro`** | Tareas complejas, arquitectura nueva o bugs difíciles. | Diseñar el sistema de combate Cliente-Servidor (anti-exploit), física avanzada de vehículos (`HingeConstraint`, `NetworkOwnership`), IA compleja de bots, misiles guiados o depuración de bugs difíciles entre múltiples scripts. |

## 2. Reglas de Ahorro de Tokens (Cuándo SÍ y cuándo NO delegar)

1. **No delegues micro-tareas de 1 solo paso:**
   - Si puedes resolver algo leyendo o editando un único archivo pequeño directamente (`inherit`), hazlo tú sin lanzar un subagente, ya que iniciar un subagente consume contexto inicial.
2. **Delega a `flash_lite` o `flash` cuando:**
   - La tarea requiera explorar varios archivos, hacer múltiples búsquedas o ejecutar varios comandos repetitivos que llenarían innecesariamente el contexto principal.
   - Se trate de implementar una pieza aislada y repetitiva (por ejemplo, crear varios prefabs o pantallas HUD simples).
3. **Delega a `pro` cuando:**
   - Exista ambigüedad técnica, riesgo de bugs de sincronización Cliente/Servidor en Roblox, problemas de física 3D o necesidad de refactorizar varios módulos a la vez.
4. **Prompts quirúrgicos para subagentes:**
   - Pasa siempre las rutas exactas de los archivos relevantes (por ejemplo `src/ReplicatedStorage/Shared/Config.luau`) y especifica qué debe devolver el subagente, evitando que lea archivos innecesarios.
