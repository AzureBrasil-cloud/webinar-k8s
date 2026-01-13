#!/bin/bash

# Script para testar o load balancing entre réplicas
# Faz múltiplas requisições e mostra qual pod está respondendo

echo "🔄 Testando Load Balancing entre pods..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar se jq está instalado
if command -v jq &> /dev/null; then
    USE_JQ=true
else
    USE_JQ=false
    echo "⚠️  jq não encontrado. Instalando para melhor formatação..."
    echo "   Se preferir, instale com: brew install jq"
    echo ""
fi

# Fazer 20 requisições
for i in {1..20}; do
    echo "📨 Requisição $i:"
    
    if [ "$USE_JQ" = true ]; then
        response=$(curl -s http://localhost:8080/instance)
        instanceId=$(echo "$response" | jq -r '.instanceId')
        hostname=$(echo "$response" | jq -r '.hostname')
        uptime=$(echo "$response" | jq -r '.uptime')
        
        echo "   🆔 Instance: $instanceId"
        echo "   🖥️  Hostname: $hostname"
        echo "   ⏱️  Uptime: $uptime"
    else
        curl -s http://localhost:8080/instance
    fi
    
    echo ""
    sleep 0.5
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Teste concluído!"
echo ""
echo "💡 Diferentes instanceId/hostname provam que o Service"
echo "   está distribuindo as requisições entre os pods!"

