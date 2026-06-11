#!/bin/bash
# External-DNS: обновление DNS-записей из Consul сервиса
# Интеграция с внешним DNS через BIND или API

CONSUL_DNS="192.168.122.91"
SERVICE="webapp"
ZONE_FILE="/etc/bind/db.diveschool.spb.ru"
TTL=10

echo "=== External-DNS Update ==="
echo "Читаем инстансы сервиса $SERVICE из Consul..."

# Получаем список IP здоровых инстансов
INSTANCES=$(curl -s "http://${CONSUL_DNS}:8500/v1/health/service/${SERVICE}?passing" | \
    python3 -c "import sys,json; [print(i['Node']['Address']) for i in json.load(sys.stdin)]" 2>/dev/null)

if [ -z "$INSTANCES" ]; then
    echo "Нет доступных инстансов!"
    exit 1
fi

echo "Найдены инстансы:"
echo "$INSTANCES"

# Генерируем DNS-зону
cat > /tmp/db.diveschool.spb.ru << ZEOF
\$TTL $TTL
@   IN SOA ns1.diveschool.spb.ru. admin.diveschool.spb.ru. $(date +%s) 3600 600 86400 $TTL
@   IN NS  ns1.diveschool.spb.ru.
ns1 IN A   170.168.91.95
ZEOF

for ip in $INSTANCES; do
    echo "webapp IN A $ip" >> /tmp/db.diveschool.spb.ru
    echo "  ✅ Добавлен A-запись: webapp → $ip"
done

# Если это production — обновляем зону
if [ -f "$ZONE_FILE" ]; then
    cp /tmp/db.diveschool.spb.ru $ZONE_FILE
    rndc reload 2>/dev/null || systemctl reload bind9 2>/dev/null
    echo "DNS-зона обновлена и загружена"
else
    echo "DNS-зона (демо-режим):"
    cat /tmp/db.diveschool.spb.ru
fi

echo ""
echo "=== Проверка DNS ==="
dig @${CONSUL_DNS} -p 8600 ${SERVICE}.service.consul +short
