# Documentation Complète du Projet d'Infrastructure Full-Stack sur GCP

## 1. Introduction et Objectif du Projet

L'objectif principal de ce projet est de déployer une application full-stack moderne, évolutive et résiliente sur Google Cloud Platform (GCP). L'application se compose d'un frontend développé avec Vite (React) et d'un backend WordPress, le tout soutenu par une base de données MySQL.

**Technologies Clés Utilisées :**

*   **Google Cloud Platform (GCP) :**
    *   **Compute Engine (GCE) :** Pour héberger les instances virtuelles du frontend, backend et monitoring.
    *   **Cloud SQL :** Service de base de données MySQL managé.
    *   **Cloud Load Balancing :** Pour distribuer le trafic entre les instances frontend.
    *   **VPC Network :** Pour créer un réseau privé et sécurisé pour les ressources.
    *   **Cloud Monitoring & Logging :** Pour la surveillance et la journalisation natives des services GCP.
    *   **Google Cloud Storage (GCS) :** Pour stocker l'état Terraform.
*   **Terraform :** Outil d'Infrastructure as Code (IaC) pour définir et provisionner l'infrastructure GCP.
*   **Ansible :** Outil de gestion de configuration pour automatiser la configuration des serveurs.
*   **Docker & Docker Compose :** Pour la conteneurisation des services de monitoring (Prometheus, Grafana) et potentiellement pour le développement local.
*   **GitHub Actions :** Pour l'intégration et le déploiement continus (CI/CD).
*   **SonarQube :** (Intégré dans le CI/CD) Pour l'analyse statique de la qualité du code.

**Environnements :**

Le projet est conçu pour supporter plusieurs environnements, typiquement :

*   **Pré-production (`preprod`) :** Pour les tests et la validation avant la mise en production.
*   **Production (`prod`) :** L'environnement live accessible aux utilisateurs (configuration similaire mais potentiellement avec plus de ressources).

## 2. Architecture Générale

L'architecture est conçue pour la séparation des préoccupations, la scalabilité et la haute disponibilité.

```mermaid
graph LR;
    subgraph "Internet"
        Utilisateur[" Utilisateur"]
    end

    subgraph "Google Cloud Platform"
        LB[" GCP Load Balancer (HTTP/S)"]

        subgraph "Frontend Tier (GCE Managed Instance Group)"
            direction LR
            FE1[" Frontend Instance 1 (Vite/Node + Nginx)"]
            FE2[" Frontend Instance 2 (Vite/Node + Nginx)"]
        end

        subgraph "Backend Tier (GCE Managed Instance Group)"
            direction LR
            BE1[" Backend Instance 1 (WordPress + Apache)"]
            BE2[" Backend Instance 2 (WordPress + Apache)"]
        end

        subgraph "Database Tier"
            DB[" Cloud SQL (MySQL)"]
        end

        subgraph "Monitoring Tier"
            MON[" Monitoring Instance (Prometheus + Grafana)"]
        end

        GCS[" GCS Bucket (Terraform State)"]
        GCR[" Google Container Registry (Images Docker)"]
        CloudMonitoring[" GCP Cloud Monitoring & Logging"]
    end

    Utilisateur --> LB;
    LB --> FE1;
    LB --> FE2;

    FE1 --> BE1;
    FE1 --> BE2;
    FE2 --> BE1;
    FE2 --> BE2;

    BE1 --> DB;
    BE2 --> DB;

    MON --> FE1;
    MON --> FE2;
    MON --> BE1;
    MON --> BE2;
    
    subgraph "CI/CD Pipeline (GitHub Actions)"
        direction LR
        Code[" Code (GitHub)"] --> ActionsRunner[" GitHub Actions Runner"];
        ActionsRunner -- "Terraform Apply" --> GCS;
        ActionsRunner -- "Terraform Apply" --> GCP_Resources["GCP Resources (GCE, SQL, LB)"];
        ActionsRunner -- "Build & Push Docker Image" --> GCR;
        ActionsRunner -- "SonarQube Scan" --> SonarQube[" SonarQube (externe)"];
        GCP_Resources -- "Logs & Metrics" --> CloudMonitoring
    end
