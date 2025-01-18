kubectl create namespace mr-do-player
kubectl apply -f mr-do-player-pv.yml
kubectl apply -f mr-do-player-pvc.yml
kubectl create configmap mr-do-snapserver-cfgmap --from-file=etc/snapserver.conf -n mr-do-player
# kubectl get configmap mr-do-snapserver-cfgmap -o yaml  -n mr-do-player
kubectl create configmap mr-do-asound-cfgmap --from-file=etc/asound.conf -n mr-do-player
# kubectl get configmap mr-do-asound-cfgmap -o yaml  -n mr-do-player
kubectl apply -f mr-do-player-service.yml
kubectl apply -f mr-do-player-deployment.yml
# kubectl apply -f mr-do-player-ingress.yml

kubectl describe pod mr-do-player -n mr-do-player
kubectl get pods -n mr-do-player -o wide
kubectl get pods --all-namespaces -o wide

# kubectl get ingress --all-namespaces -o wide
# kubectl describe ingress -n mr-do-player

kubectl get pv --all-namespaces -o wide
kubectl get pvc --all-namespaces -o wide
kubectl describe pv mr-do-player-pv-data -n mr-do-player
kubectl describe pvc mr-do-player-pvc-data -n mr-do-player

kubectl get configmap --all-namespaces -o wide
kubectl get svc --all-namespaces
kubectl get services  -n mr-do-player -o wide
kubectl describe services mr-do-player-service -n mr-do-player

kubectl get all -n mr-do-player
