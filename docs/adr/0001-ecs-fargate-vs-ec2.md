# ADR 0001 — ECS Fargate plutôt qu'ECS sur EC2 / Auto Scaling Group

- **Statut :** Accepté
- **Date :** 2026-06-03
- **Décideurs :** Équipe plateforme / DevOps

## Contexte

Le tier applicatif est conteneurisé (image Docker Python/Flask) et doit être
hautement disponible, auto-scalé et exploité avec un minimum de charge
opérationnelle. Trois options de calcul ont été envisagées pour exécuter ces
conteneurs sur AWS :

1. **ECS sur EC2** — un cluster ECS adossé à un Auto Scaling Group (ASG)
   d'instances EC2 que nous gérons.
2. **ECS sur Fargate** — calcul *serverless* pour conteneurs ; AWS gère les
   hôtes sous-jacents.
3. **EKS (Kubernetes)** — orchestrateur Kubernetes managé.

EKS est volontairement écarté ici : sa puissance (et sa complexité) est traitée
dans le **projet 03** du portfolio. Le débat se concentre donc sur **Fargate vs
EC2/ASG**.

## Décision

Nous retenons **ECS sur Fargate** pour le tier applicatif.

Le service ECS utilise le *launch type* `FARGATE` (avec `FARGATE_SPOT` disponible
comme capacity provider), des tâches de 0,25 vCPU / 512 Mo réparties sur 2 AZ,
et une politique d'autoscaling par suivi de cible sur le CPU.

## Justification

| Critère | ECS sur EC2 / ASG | **ECS sur Fargate** |
|---------|-------------------|---------------------|
| Gestion des hôtes (patchs OS, AMI) | À notre charge | **Aucune — géré par AWS** |
| Surface d'attaque | OS + agent ECS exposés | **Réduite (pas d'hôte à durcir)** |
| Modèle de coût | Instances payées même sous-utilisées | **Paiement à la tâche/seconde** |
| Densité / *bin packing* | À optimiser manuellement | Non applicable (1 tâche = ressources dédiées) |
| Vitesse de mise à l'échelle | Dépend du démarrage d'instances | **Démarrage de tâche rapide** |
| Charge opérationnelle | Élevée (capacité, drain, mises à jour) | **Faible** |

Arguments décisifs pour ce projet :

- **Zéro gestion de serveur** — pas d'AMI à maintenir, pas de cycle de patch
  d'OS, pas de capacité de cluster à dimensionner. C'est l'objectif « 100 % IaC,
  zéro ClickOps, faible charge opérationnelle » du portfolio.
- **Sécurité** — chaque tâche s'exécute dans un environnement isolé géré par
  AWS ; il n'y a pas d'hôte EC2 partagé à durcir ni à surveiller.
- **Coût adapté à une charge variable et modeste** — pour une démo au trafic
  intermittent, payer à la tâche évite le coût d'instances EC2 allumées en
  permanence. `FARGATE_SPOT` permet d'aller plus loin sur les charges
  tolérantes aux interruptions.
- **Scalabilité simple** — l'autoscaling agit directement sur le nombre de
  tâches, sans avoir à coordonner un ASG d'instances en parallèle.

## Conséquences

### Positives

- Charge opérationnelle minimale ; l'équipe se concentre sur l'application.
- Isolation et posture de sécurité renforcées par défaut.
- Mise à l'échelle fine et rapide, à la tâche.

### Négatives / limites

- **Coût unitaire** plus élevé qu'EC2 réservé pour une charge **constante et
  prévisible** à grande échelle : à fort volume soutenu, EC2 (avec Savings Plans)
  peut redevenir compétitif.
- **Moins de contrôle bas niveau** : pas d'accès SSH à l'hôte, pas de démon
  personnalisé sur l'hôte, choix de GPU/instances spécialisées limité.
- **Démarrage à froid** d'une tâche légèrement supérieur à la réutilisation d'un
  hôte EC2 déjà chaud (atténué ici par un `min_capacity` de 2).

### Réversibilité

ECS abstrait le type de calcul : migrer vers un capacity provider EC2/ASG plus
tard ne nécessiterait **pas de réécrire l'application ni la task definition**,
seulement d'ajouter un capacity provider et d'ajuster la stratégie. La décision
est donc peu coûteuse à revoir.
