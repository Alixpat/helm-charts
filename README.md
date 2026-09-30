# helm-charts

Charts Helm maintenus par [Alixpat](https://github.com/Alixpat).

## Utilisation

```bash
helm repo add alixpat https://alixpat.github.io/helm-charts
helm repo update
helm search repo alixpat
```

## Charts disponibles

| Chart | Description |
|-------|-------------|
| [meshcentral](charts/meshcentral) | Serveur de gestion et prise en main à distance [MeshCentral](https://github.com/Ylianst/MeshCentral) |

## Développement

```bash
helm lint charts/<chart>
helm template test charts/<chart>
```

Chaque modification d'un chart doit incrémenter `version` dans son `Chart.yaml`.
Au merge sur `main`, [chart-releaser](https://github.com/helm/chart-releaser-action) publie
une release GitHub et met à jour l'index sur la branche `gh-pages`.
