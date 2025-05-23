// firebase-messaging-sw.js
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

// Configuração do Firebase com os dados corretos do projeto
firebase.initializeApp({
  apiKey: "AIzaSyAa6aXPBKbPV1qehRJCjffdUiIwfUpSLUg",
  authDomain: "painel-agrogeo.firebaseapp.com",
  projectId: "painel-agrogeo",
  storageBucket: "painel-agrogeo.firebasestorage.app", // Corrigido para o domínio correto
  messagingSenderId: "213167893548",
  appId: "1:213167893548:web:90aca852e1dbae3085f589",
  measurementId: "G-RQFZXFEXD0"
});

const messaging = firebase.messaging();

// Configuração para mensagens em background
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Recebida mensagem em background:', payload);
  
  // Extrai título e corpo da notificação com fallbacks seguros
  const notificationTitle = payload.notification?.title || 'AGROGEO BRASIL';
  const notificationOptions = {
    body: payload.notification?.body || 'Nova notificação',
    icon: '/favicon.png',
    badge: '/badge-icon.png', // Opcional: ícone de badge para dispositivos que suportam
    data: {
      url: payload.data?.click_action || '/' // URL para abrir ao clicar na notificação
    },
    // Vibração personalizada (opcional)
    vibrate: [100, 50, 100],
    // Ações personalizadas (opcional)
    actions: [
      {
        action: 'open',
        title: 'Abrir'
      }
    ]
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Configuração para cliques em notificações
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] Notificação clicada');
  event.notification.close();
  
  // URL para abrir, com fallback para raiz
  const urlToOpen = event.notification.data?.url || '/';
  
  // Isso garante que o cliente tenha foco se já estiver aberto
  event.waitUntil(
    clients.matchAll({
      type: 'window',
      includeUncontrolled: true // Importante para PWAs
    })
    .then(function(clientList) {
      // Tenta encontrar uma janela já aberta para focar
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        // Verifica se já existe uma janela aberta e foca nela
        if (client.url.includes(urlToOpen) && 'focus' in client) {
          return client.focus();
        }
      }
      
      // Se não encontrou janela aberta, abre uma nova
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});

// Evento para quando uma notificação é fechada sem ser clicada
self.addEventListener('notificationclose', function(event) {
  console.log('[firebase-messaging-sw.js] Notificação fechada sem interação');
});

// Evento de instalação do Service Worker
self.addEventListener('install', function(event) {
  console.log('[firebase-messaging-sw.js] Service Worker instalado');
  self.skipWaiting(); // Ativa imediatamente, sem esperar refresh
});

// Evento de ativação do Service Worker
self.addEventListener('activate', function(event) {
  console.log('[firebase-messaging-sw.js] Service Worker ativado');
  return self.clients.claim(); // Toma controle de todos os clientes
});
