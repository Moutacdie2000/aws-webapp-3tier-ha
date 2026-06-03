# ADR 0002, RDS PostgreSQL en Multi-AZ et stratégie de bascule

- **Statut :** Accepté
- **Date :** 2026-06-03
- **Décideurs :** Équipe plateforme / DevOps

## Contexte

Le tier données doit offrir une base relationnelle **PostgreSQL** persistante,
chiffrée et **hautement disponible**, cohérente avec l'objectif de tolérance à
la perte d'une zone de disponibilité (AZ) du reste de l'architecture.

Options envisagées :

1. **RDS PostgreSQL, instance unique (Single-AZ).**
2. **RDS PostgreSQL, Multi-AZ « instance de secours » (1 standby).**
3. **RDS PostgreSQL, Multi-AZ « cluster » (2 standbys lisibles, Multi-AZ DB
   Cluster).**
4. **Amazon Aurora PostgreSQL-compatible.**

## Décision

Nous retenons **RDS PostgreSQL en déploiement Multi-AZ avec instance de secours**
(option 2) : `multi_az = true` sur l'`aws_db_instance`.

La configuration applique en outre : chiffrement au repos via **clé KMS dédiée**,
mot de passe généré et stocké dans **Secrets Manager**, **sauvegardes
automatiques** (rétention 7 jours), `rds.force_ssl` pour le chiffrement en
transit, et Enhanced Monitoring + Performance Insights pour l'observabilité.

## Justification

| Critère | Single-AZ | **Multi-AZ standby** | Multi-AZ Cluster | Aurora |
|---------|-----------|----------------------|------------------|--------|
| Tolérance à la perte d'une AZ | ❌ | ✅ | ✅ | ✅ |
| Bascule automatique | ❌ | ✅ (60–120 s) | ✅ (plus rapide) | ✅ |
| Réplicas en lecture inclus |, | Non | 2 (lisibles) | Oui |
| Compatibilité PostgreSQL standard | ✅ | ✅ | ✅ | ✅ (compatible) |
| Coût | € | €€ | €€€ | €€€ |
| Complexité | Faible | **Faible** | Moyenne | Moyenne |

Arguments pour le **Multi-AZ standby** :

- **Répond exactement au besoin de HA** du projet (tolérance à la perte d'une
  AZ) sans surdimensionner.
- **Bascule automatique gérée par AWS** : aucune logique applicative à écrire.
- **Coût maîtrisé** : un seul standby, contrairement au Multi-AZ Cluster (2) ou
  à Aurora, dont la valeur (réplicas lisibles, débit élevé) n'est pas requise
  pour cette démo.
- **Simplicité** : PostgreSQL « vanilla », sans spécificité Aurora à apprendre,
  ce qui maximise la lisibilité pédagogique du dépôt.

## Stratégie de bascule (failover)

### Mécanisme

L'instance primaire réplique de façon **synchrone** vers le standby (autre AZ).
En cas d'incident sur la primaire, défaillance matérielle, indisponibilité de
l'AZ, ou opération de maintenance/patch, RDS **promeut automatiquement** le
standby et **repointe le nom DNS du point de terminaison** vers la nouvelle
primaire. Durée typique : **60 à 120 secondes**.

### Implications applicatives

- L'application se connecte **toujours par le nom DNS** du point de terminaison
  (`...rds.amazonaws.com`), **jamais par une IP** : la bascule est donc
  transparente côté chaîne de connexion.
- Les connexions ouvertes au moment de la bascule sont **coupées**.
  L'application doit donc **rétablir ses connexions** (et idéalement utiliser un
  pool avec *retry*). La route `/db` de la démo illustre la reconnexion : elle
  renvoie `503` pendant la bascule, puis `200` une fois le standby promu.
- Réduire le TTL DNS côté client (RDS publie un TTL court) accélère la prise en
  compte du nouveau point de terminaison.

### Déclenchement et test

- **Automatique** sur incident réel ou perte d'AZ.
- **Manuel** pour validation : un `reboot` avec l'option *failover* force une
  bascule contrôlée (`aws rds reboot-db-instance --force-failover`), voir la
  section « Tests & validation » du README.

## Conséquences

### Positives

- Tolérance à la panne d'une AZ pour le tier données, cohérente avec les autres
  tiers.
- Patchs et maintenance applicables avec une interruption minimale (bascule
  pendant la fenêtre de maintenance).
- Sauvegardes + chiffrement + secrets gérés couvrent durabilité et sécurité.

### Négatives / limites

- **Coût doublé** sur le calcul de la base (primaire + standby payés).
- Le standby **n'est pas lisible** : il n'apporte pas de capacité de lecture
  supplémentaire (pour cela, il faudrait des *read replicas* ou Aurora).
- La bascule, bien qu'automatique, induit une **brève indisponibilité** (~1–2
  min) à absorber côté applicatif.

### Évolution possible

Si un besoin de **montée en charge des lectures** ou de **RTO plus court**
apparaissait, la migration vers **Aurora PostgreSQL** ou un **Multi-AZ DB
Cluster** serait l'étape suivante, sans changement du modèle de données.
