import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'br.com.nutria',
  appName: 'NutrIA',
  webDir: 'web',
  server: {
    androidScheme: 'https',
    cleartext: true,
    // URL do servidor Phoenix (dev). Ajuste o IP para o host real no dispositivo.
    url: process.env.CAPACITOR_SERVER_URL || 'https://nutria.shares.zrok.io'
  }
};

export default config;
