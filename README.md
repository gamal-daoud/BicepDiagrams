

# Génération de diagrammes d'infrastructure à partir de templates Bicep

#  Résumé:
Ce projet a pour but de développer un outil de visualisation de templates Bicep, un langage d'Infrastructure as Code pour décrire des ressources du cloud Azure et les provisionner automatiquement.

#  Projet Technique:
- Mots Clés : Diagrammes, Bicep, Infrastructure,
- Équipe/Entité concernée :
- Créé le 2026-03-12
- Assigné le 2026-04-28
- Sujet affecté à Gamal Daoud Youssouf

#  Description du Projet:
Ce projet vise à combler le manque de visibilité sur les déploiements Azure en créant un outil capable de générer des diagrammes d'infrastructure directement depuis les templates Bicep.


#  Encadrement:
- Philippe Merle
- contact : [philippe.merle@univ-lille.fr]

#  Contexte:
Bicep [1] est un langage d'Infrastructure as Code [2] pour décrire la configuration de ressources du cloud Azure (machines virtuelles, stockage, réseaux virtuels, etc.) puis de provisionner ces ressources de manière automatisée et reproductible.


Les templates Bicep, bien que puissants pour l'automatisation des déploiements sur Azure, souffrent d'un manque de visibilité. Il est difficile de comprendre l'architecture d'une application ou d'un service sans examiner attentivement le code source. De plus, les dépendances entre les ressources ne sont pas toujours claires, ce qui peut entraîner des erreurs lors des modifications ou des suppressions de ressources.


#  Problématique:
Un template Bicep peut devenir rapidement complexe à appréhender et comprendre dans son ensemble.


#  Travail à effectuer:
Ce projet vise à développer un outil de visualisation de templates Bicep. Pour cela, l'outil génèrera des diagrammes d'infrastructure à partir de templates Bicep. Cet outil s'inspirera des outils AWS CloudFormation Diagrams [3] et KubeDiagrams [4] développés dans l'équipe de recherche Spirals.

# Plan de travail :

1. Etablir un état de l'art des outils existants de génération de diagrammes pour Bicep.
2. Etudier les constructions du langage Bicep.
3. Proposer une transformation des constructions du langage Bicep en éléments d'un diagramme d'infrastructure (noeud, arête, cluster).
4. Implanter la transformation en utilisant la bibliothèque Diagrams [5].
5. Appliquer l'outil développé sur le plus grand nombre de templates Bicep obtenus sur GitHub [6].



#  Objectif:
L'objectif de ce projet est de développer un outil capable de générer des diagrammes d'infrastructure à partir de templates Bicep. Ces diagrammes permettront de visualiser l'architecture des déploiements Azure, de comprendre les dépendances entre les ressources et de faciliter la maintenance et l'évolution des applications.

#  Cahier des charges:
Le projet devra permettre de générer des diagrammes d'infrastructure à partir de templates Bicep. Ces diagrammes devront permettre de visualiser l'architecture des déploiements Azure, de comprendre les dépendances entre les ressources et de faciliter la maintenance et l'évolution des applications.

#  Livrables:
- Un outil capable de générer des diagrammes d'infrastructure à partir de templates Bicep.
- Des diagrammes d'infrastructure permettant de visualiser l'architecture des déploiements Azure, de comprendre les dépendances entre les ressources et de faciliter la maintenance et l'évolution des applications.
- Une documentation permettant de comprendre l'outil et son utilisation.

#  Modalités:
- Le projet devra être réalisé en respectant les bonnes pratiques de développement.

#  Validation du projet:
Le projet sera validé par le responsable de l'encadrement, Philippe Merle.

#  Technologie et Prérequis (Outils utilises):
- Bicep
- Diagrams(Python)
- Terraform
- Docker
- Kubernetes
- Azure DevOps


# Bibliographie:
[1] https://learn.microsoft.com/fr-fr/azure/azure-resource-manager/bicep/

[2] https://fr.wikipedia.org/wiki/Infrastructure_as_code

[3] https://github.com/philippemerle/AWS-CloudFormation-Diagrams

[4] https://github.com/philippemerle/KubeDiagrams

[5] https://diagrams.mingrammer.com

[6] https://github.com/search?q=path%3A*.bicep&type=code
