# excel-to-internal-table
Import data from excel file

# Simular tcode MIRO (geração de dados de NF) #

[![N|Solid](https://wiki.scn.sap.com/wiki/download/attachments/1710/ABAP%20Development.png?version=1&modificationDate=1446673897000&api=v2)](https://www.sap.com/brazil/developer.html)

~~Quando Deus der coragem~~ Futuramente eu vou melhorar o codigo e mudar com uma boa documentação.
Desenvolvimento para similar a execução do tcode MIRO e retorna dados da NF

## Necessidade ##
De acordo com os Pedidos de Compras (que são acessados pela `ME23N`), será criada _Entrada de Mercadoria_ pela transação `MIRO` e depois a _Nota Fiscal_ (que pode ser acessada pela transação `J1B3N`). Houve a necessidade de que, antes disso, seja feita apenas uma simulação e os dados da _Nota Fiscal_ fossem recuperados para uma verificação, entender se esta da maneira esperada a configuração de Impostos ~~ou sei la mesmo porque o funcional inventou isso viu~~.

## Tecnologia adotada ##
A criação da classe sera para atender a necessidade e provera os dados de _Nota Fiscal_ caso seja preciso alguma validação referente a impostos.

## Solução ##
