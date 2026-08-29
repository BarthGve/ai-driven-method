---
description: Affiche le pipeline driven — l'ordre des phases et la règle unique
disable-model-invocation: true
---
# driven — Pipeline

Règle unique : interdit de coder en direct. Chaque feature passe par le pipeline.

## Une fois par projet
1. /dm-prd <cible>       — cadre le kill : SaaS cible, périmètre, QUOI + POURQUOI
2. /dm-stories           — découpe en user stories agentic-ready
3. /dm-stories-review    — relit le découpage vs le périmètre du PRD (contexte vierge)
4. /dm-architect         — stack, conventions, rules
5. /dm-design-system     — capture le design system global (tokens, composants)

## Par story (une feature = un cycle = une branche = une PR)
6. /dm-research <story>  — explore le contexte réel (code actuel, API, pièges)
7. /dm-design <story>    — décline l'écran depuis le design system (si UI)
8. /dm-plan <story>      — éclate la story en tâches
9. /dm-execute <story>   — code en TDD (subagent isolé)
10. /dm-review <story>   — review anti-hallucination + gate
11. /dm-ship <story>     — ouvre la PR ; merge manuel par défaut (cf. AGENTS.md)

Bloqué en review sur un critique → retour /dm-execute (fix mode). Sinon → /dm-ship.

## Orchestrateur
/dm-orchestrator <story> — enchaîne les 6 temps du cycle en une commande.
Il ne remplace rien : mêmes contrats, mêmes subagents, mêmes gates que les
commandes unitaires. Il s'arrête sur 2 questions bloquantes : valider le plan
(écrit dans le fichier plan), confirmer le ship. Cycle routinier → orchestrateur ;
besoin de piloter ou inspecter une phase → commandes unitaires.

Où en est le projet (avancement par story, prochaine commande) : /dm-status
