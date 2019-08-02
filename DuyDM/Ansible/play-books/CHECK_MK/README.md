## Run play-books CHECKMK_SERVER

```
ansible-playbook install-checkmk-c7.yml --extra-vars '{"omd_name":"admin","pass_cmkadmin":"123456aA"}'
```

![](../images/img-play-books/Screenshot_347.png)
![](../images/img-play-books/Screenshot_348.png)

## Check 

```
http://ip-server/
```

![](../img-play-books/Screenshot_346.png)


