## Run play-books install grafana-server, add datasource. import file .json chuẩn.

```
ansible-playbook install-grafana62-c7.yml --extra-vars '{"pass_admin":"123456aA"}'
```

![](../img-play-books/Screenshot_349.png)
![](../img-play-books/Screenshot_350.png)

## Check 

```
http://ip-server:3000/
```

![](../img-play-books/Screenshot_351.png)
![](../img-play-books/Screenshot_352.png)
![](../img-play-books/Screenshot_353.png)







