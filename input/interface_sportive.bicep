// ============================================
// CHAMPIONS LEAGUE 2026 BUDAPEST - INTERFACE SPORTIVE
// Tableau complet avec relations de tournoi
// ============================================

param location string = resourceGroup().location

// ============================================
// TROPHÉE — Centre du tableau
// ============================================

resource coupe 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'coupecl26'
  location: location
  tags: { title: 'CHAMPIONS LEAGUE', subtitle: 'BUDAPEST 2026 FINAL', role: 'trophy' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

// ============================================
// FINALES (Gauche + Droite)
// ============================================

resource fingauche 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'finalgauche26'
  location: location
  tags: { label: 'FINALE GAUCHE', role: 'final' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [coupe]
}

resource findroite 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'finaldroite26'
  location: location
  tags: { label: 'FINALE DROITE', role: 'final' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [coupe]
}

// ============================================
// DEMI-FINALES GAUCHE
// ============================================

resource sg1 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'demifinaleg126'
  location: location
  tags: { label: 'DEMI-FINALE G1', role: 'semifinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [fingauche]
}

resource sg2 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'demifinaleg226'
  location: location
  tags: { label: 'DEMI-FINALE G2', role: 'semifinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [fingauche]
}

// ============================================
// DEMI-FINALES DROITE
// ============================================

resource sd1 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'demifinaled126'
  location: location
  tags: { label: 'DEMI-FINALE D1', role: 'semifinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [findroite]
}

resource sd2 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'demifinaled226'
  location: location
  tags: { label: 'DEMI-FINALE D2', role: 'semifinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [findroite]
}

// ============================================
// QUARTS DE FINALE — CÔTÉ GAUCHE
// ============================================

resource qg1 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'quartfinalg126'
  location: location
  tags: { label: 'PSG vs Chelsea', role: 'quarterfinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [sg1]
}

resource qg2 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'quartfinalg226'
  location: location
  tags: { label: 'Galatasaray vs Liverpool', role: 'quarterfinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [sg1]
}

resource qg3 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'quartfinalg326'
  location: location
  tags: { label: 'Real Madrid vs Man City', role: 'quarterfinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [sg2]
}

resource qg4 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'quartfinalg426'
  location: location
  tags: { label: 'Atalanta vs Bayern', role: 'quarterfinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [sg2]
}

// ============================================
// QUARTS DE FINALE — CÔTÉ DROITE
// ============================================

resource qd1 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'quartfinald126'
  location: location
  tags: { label: 'Newcastle vs Barcelona', role: 'quarterfinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [sd1]
}

resource qd2 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'quartfinald226'
  location: location
  tags: { label: 'Atletico vs Tottenham', role: 'quarterfinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [sd1]
}

resource qd3 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'quartfinald326'
  location: location
  tags: { label: 'Bodo vs Sporting', role: 'quarterfinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [sd2]
}

resource qd4 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'quartfinald426'
  location: location
  tags: { label: 'Leverkusen vs Arsenal', role: 'quarterfinal' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [sd2]
}

// ============================================
// ÉQUIPES — CÔTÉ GAUCHE
// PSG, Chelsea → QG1 → SG1 → FG → COUPE
// Galatasaray, Liverpool → QG2 → SG1
// Real Madrid, Man City → QG3 → SG2 → FG
// Atalanta, Bayern → QG4 → SG2
// ============================================

resource psg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'psgcl26'
  location: location
  tags: { team: 'Paris Saint-Germain', country: 'France', icon: 'paris-saint-germain.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qg1]
}

resource chelsea 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'chelseacl26'
  location: location
  tags: { team: 'Chelsea FC', country: 'England', icon: 'chelsea.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qg1]
}

resource galatasaray 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'galatasaray26'
  location: location
  tags: { team: 'Galatasaray SK', country: 'Turkey', icon: 'galatasaray.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qg2]
}

resource liverpool 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'liverpcl26'
  location: location
  tags: { team: 'Liverpool FC', country: 'England', icon: 'liverpool.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qg2]
}

resource real 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'realcl26'
  location: location
  tags: { team: 'Real Madrid', country: 'Spain', icon: 'real-madrid.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qg3]
}

resource mancity 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'mancitycl26'
  location: location
  tags: { team: 'Manchester City', country: 'England', icon: 'manchester-city.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qg3]
}

resource atalanta 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'atalantacl26'
  location: location
  tags: { team: 'Atalanta BC', country: 'Italy', icon: 'atalenta.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qg4]
}

resource bayern 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'bayerncl26'
  location: location
  tags: { team: 'FC Bayern Munich', country: 'Germany', icon: 'bayern-munchen.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qg4]
}

// ============================================
// ÉQUIPES — CÔTÉ DROITE
// Newcastle, Barcelona → QD1 → SD1 → FD → COUPE
// Atletico, Tottenham → QD2 → SD1
// Bodo, Sporting → QD3 → SD2 → FD
// Leverkusen, Arsenal → QD4 → SD2
// ============================================

resource newcastle 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'newcastlecl26'
  location: location
  tags: { team: 'Newcastle United', country: 'England', icon: 'newcastle.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qd1]
}

resource barcelona 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'barcelonacl26'
  location: location
  tags: { team: 'FC Barcelona', country: 'Spain', icon: 'barcelona.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qd1]
}

resource atletico 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'atleticocl26'
  location: location
  tags: { team: 'Atletico de Madrid', country: 'Spain', icon: 'atletico-de-madrid.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qd2]
}

resource tottenham 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'tottenhcl26'
  location: location
  tags: { team: 'Tottenham Hotspur', country: 'England', icon: 'tottenham-hotspur.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qd2]
}

resource bodo 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'bodocl26'
  location: location
  tags: { team: 'FK Bodo/Glimt', country: 'Norway', icon: 'bodo.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qd3]
}

resource sporting 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'sportingcl26'
  location: location
  tags: { team: 'Sporting CP', country: 'Portugal', icon: 'sporting.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qd3]
}

resource leverkusen 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'leverkusencl26'
  location: location
  tags: { team: 'Bayer Leverkusen', country: 'Germany', icon: 'bayern-leverkusen.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qd4]
}

resource arsenal 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'arsenalcl26'
  location: location
  tags: { team: 'Arsenal FC', country: 'England', icon: 'arsenal.png', status: 'qualified' }
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  dependsOn: [qd4]
}

// ============================================
// OUTPUTS
// ============================================

output competition string = 'UEFA Champions League 2026'
output qualifiedTeamsCount int = 16
output message string = 'Tableau de la Champions League généré'
