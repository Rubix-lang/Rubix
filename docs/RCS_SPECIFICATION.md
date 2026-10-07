# Rubix Cascading Stylesheets (RCS) Engine

RCS is a native, high-performance declarative styling and animation engine built directly in pure Rubix. It parses, resolves, optimizes, and emits web-standard CSS with zero JavaScript dependencies.

---

## 1. Engine Highlights

- **Pure Rubix Implementation**: Fully implemented without external parsers or CSS runtime dependencies.
- **Micro-Motion & Animation Verbs**: First-class feel-word durations, motion verbs, and timing functions that synthesize standard CSS `@keyframes`.
- **Deduplication & Rule Merging**: Automatic deduplication of generated `@keyframes` and merging of identical selectors.
- **Adaptive Layout**: Automatic flexbox context injection on `gap` properties and layout shorthands.
- **Accessibility & Reduced Motion**: Automatically wraps motion triggers in `@media (prefers-reduced-motion: reduce)` media queries.

---

## 2. Test Verification

The RCS engine is validated by an extensive native test suite in `tests/rcs_engine_test.bix` executed via `./scripts/test.sh`:

1. Lexer basic tokenization
2. Parser single rule
3. Parser multiple rules
4. Parser motion verbs
5. Parser `when` condition
6. Property alias mapping
7. Radius value aliases
8. Feel-word durations
9. Motion verb checker
10. Specificity scoring
11. Value resolution
12. Bake radius -> WebStyle
13. Bake shadow -> WebStyle
14. Bake center layout
15. Bake motion -> animation
16. CSS emitter output
17. CSS emitter `@keyframes`
18. Inline parser
19. Color token mapping
20. Layout helpers
21. Golden: Kid Counter CSS output
22. Golden: `var()` syntax preservation
23. Golden: Pseudo-selector preservation
24. Golden: `:root` selector preservation
25. Golden: Duplicate flex suppression
26. BUG-1 Keyframe deduplication
27. BUG-2 Same selector rule merging
28. BUG-3 Comma-composed animations
29. BUG-4 Trigger-to-pseudo mapping (`:focus`, `:active`)
30. BUG-5 `when` state rules preserved with comment
31. BUG-6 `once` iteration emits `1 forwards`
32. BUG-7 Bare shorthand motion verb
33. BUG-8 `gap` auto-injects flex context
34. At-rules (`@import`, `@media`)
35. CSS nesting (`&` and descendant)
36. `!important` value resolution
37. Property alias expansion (`pointer`, `z`, `op`)
38. Motion triggers & reduced-motion a11y wrap

**Status**: 38/38 Tests Passed (100% clean).
