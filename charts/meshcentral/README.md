# meshcentral

Chart Helm pour [MeshCentral](https://github.com/Ylianst/MeshCentral), basé sur l'image officielle
`ghcr.io/ylianst/meshcentral`. Version minimale : Ingress (TLS terminé par Traefik), base NeDB,
un seul pod.

## Installation

```bash
helm repo add alixpat https://alixpat.github.io/helm-charts
helm install meshcentral alixpat/meshcentral \
  --namespace meshcentral --create-namespace \
  --set hostname=mesh.example.com \
  --set ingress.tlsSecretName=mon-certificat-tls
```

Seule valeur requise : `hostname`.

## Connexion

Un compte administrateur (`admin.username`, par défaut `admin`) est créé au premier démarrage.
Son mot de passe est généré puis conservé dans un Secret :

```bash
kubectl get secret -n meshcentral meshcentral-admin -o jsonpath='{.data.password}' | base64 -d; echo
```

`admin.password` permet de l'imposer. Il n'est appliqué qu'à la création du compte : changez-le
ensuite depuis l'interface.

## Installer les agents

Au démarrage, le chart crée le groupe `agentGroup` (par défaut « Serveurs ») s'il n'existe pas, et
publie un script d'installation prêt à l'emploi. Sur chaque VM, en root :

```bash
curl -fsSL https://mesh.example.com/agent/install.sh | bash -s -- prod,web,zone-a "Serveur web"
```

- Les deux paramètres sont facultatifs : étiquettes séparées par des virgules, puis description.
  Préférez des caractères sans accents (ils sont mal décodés par l'agent).
- La VM apparaît automatiquement dans le groupe, avec son nom d'hôte, ses étiquettes et sa description.
- Relancée sur une VM déjà équipée, la commande met seulement à jour étiquettes et description.
- Dans l'interface, « Trier par : Tags » regroupe les machines par étiquette (choix mémorisé par utilisateur).
- La VM doit résoudre `hostname`, joindre le port 443 de Traefik et faire confiance à son certificat TLS.
- À lancer au premier démarrage de chaque VM (cloud-init, Ansible), **pas dans un template** :
  des VM clonées avec un agent déjà installé partageraient la même identité.

## Values

| Value | Défaut | Description |
|-------|--------|-------------|
| `hostname` | `""` | **Requis.** Nom DNS public. Inscrit dans les agents : le changer impose de les réinstaller. |
| `image.registry` | `ghcr.io` | Registry de l'image (registry interne en airgap) |
| `image.repository` | `ylianst/meshcentral` | |
| `image.tag` | `1.2.6` | Version de MeshCentral |
| `admin.username` | `admin` | Compte administrateur créé au démarrage |
| `admin.password` | `""` | Vide = généré |
| `agentGroup` | `Serveurs` | Groupe dans lequel les agents s'inscrivent (créé automatiquement) |
| `ui.title` | `""` | Titre des pages (vide = « MeshCentral ») |
| `ingress.className` | `""` | Vide = IngressClass par défaut du cluster |
| `ingress.tlsSecretName` | `""` | Secret TLS existant, dans le namespace de la release. Vide = certificat par défaut de Traefik |
| `persistence.storageClass` | `""` | Vide = StorageClass par défaut du cluster |
| `persistence.dataSize` | `2Gi` | Certificats serveur et base NeDB |
| `persistence.filesSize` | `10Gi` | Fichiers déposés par les utilisateurs |
| `persistence.backupsSize` | `10Gi` | Sauvegardes |
| `resources` | `{}` | Ressources du conteneur |
| `config` | `{}` | Surcharge libre du `config.json` (fusion profonde, clés en minuscules) |

Exemple de `config` (sauvegardes automatiques) :

```yaml
config:
  settings:
    autobackup:
      backupintervalhours: 24
      keeplastdaysbackup: 10
```

## Fonctionnement

- MeshCentral écoute en HTTP sur 4430, derrière l'Ingress (`tlsoffload`). L'Ingress n'écoute que sur
  l'entrypoint Traefik `websecure` : pas de redirection HTTP→HTTPS.
- MeshCentral récupère le certificat présenté par Traefik sur `https://<hostname>/` : cette URL doit
  être joignable **depuis le pod**.
- Interface épurée : bandeau et pied de page masqués, recherche étendue au nom système et au groupe.
- Un conteneur `agent-bootstrap` crée le groupe d'agents (via `meshctrl` et la clé de connexion
  serveur, indépendante du mot de passe admin) et publie `/agent/install.sh`.
- Les étiquettes et la description viennent du fichier `meshagent.tag` de l'agent, écrit par le
  script d'installation et relu à chaque connexion.
- Le `config.json` est généré dans un Secret. Toute modification redémarre le pod.
- Les PVC sont conservés après `helm uninstall` (`helm.sh/resource-policy: keep`).
- **Sauvegardez le volume `data`** : il contient les certificats serveur, sa perte rend tous les
  agents orphelins.

## Airgap

L'image officielle démarre sans accès réseau : il suffit de la copier dans le registry interne et de
renseigner `image.registry`. Les agents sont téléchargés depuis le serveur MeshCentral lui-même.
