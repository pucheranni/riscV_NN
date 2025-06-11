# riscV_NN
[Skip to content](https://ic.unicamp.br/~allanms/mc404-S12025/trab/trabalho-1/#iris-em-assembly-redes-neurais-com-risc-v)

# 🧠 Iris em Assembly – Redes Neurais com RISC-V

## 💡 Descrição - (1.0 na Média Final )

Prepare-se para embarcar em uma jornada onde o poder das redes neurais encontra a elegância do assembly! Neste trabalho, você deve implementar em Assembly RISC-V o processo de inferência de uma rede neural, uma dentre quatro possíveis variações da **IrisNet**, baseada no conjunto de dados Iris.

O conjunto de dados Iris é um dos datasets mais clássicos e amplamente utilizados no campo da estatística e do aprendizado de máquina. Ele foi introduzido por Ronald Fisher em 1936 e contém informações sobre 150 amostras de flores da espécie Iris, divididas igualmente entre três espécies: Iris setosa, Iris versicolor e Iris virginica. Cada amostra é descrita por quatro características numéricas: comprimento e largura da sépala, e comprimento e largura da pétala — todas medidas em centímetros. A simplicidade, o balanceamento das classes e a separabilidade visual tornam o Iris ideal para tarefas introdutórias de classificação, como aquela que você implementará neste projeto com Assembly RISC-V.

[![example](https://i.imgur.com/oXcxWEA.png)](https://i.imgur.com/oXcxWEA.png)

Tudo será feito com **números inteiros**. Você receberá os **pesos da rede neural** (em formato de string JSON), a **estrutura da arquitetura**, e uma **entrada de 4 inteiros** representando medidas florais (em milímetros).

## Como funciona o processo de inferência em uma Rede Neural?

A inferência, ou _forward pass_, em uma rede neural é o processo pelo qual uma entrada é propagada pelas camadas da rede até gerar uma saída. Esse processo simula o comportamento dos neurônios biológicos, onde cada unidade (neurônio artificial) recebe sinais de entrada, realiza um processamento e produz um sinal de saída.

## Inspiração Biológica

A rede neural artificial é inspirada em um neurônio biológico. Na analogia:

- Os **inputs** ( `x`) funcionam como os _dendritos_, que recebem os sinais de entrada;
- Os **pesos** ( `w`) representam a força da conexão entre os neurônios;
- O **bias** ( `b`) funciona como um deslocamento que ajuda a ajustar o resultado;
- Uma **função de ativação não-linear** ( `f`) determina se o neurônio será ativado ou não.

[![neurônio](https://i.imgur.com/LbXz159.png)](https://i.imgur.com/LbXz159.png)

## Cálculo Matemático do Neurônio

Cada neurônio realiza uma média ponderada das entradas, somando o bias, e aplica a função de ativação:

z\[c\]1=w\[c\]T1⋅a\[c−1\]+b1a\[c\]1=f(z\[c\]1)z1\[c\]=w1\[c\]T⋅a\[c−1\]+b1a1\[c\]=f(z1\[c\])

Onde:
\- a\[c−1\]a\[c−1\] são as ativações da camada anterior;
\- w\[c\]1w1\[c\] é o vetor de pesos do primeiro neurônio da camada atual;
\- $ b\_1 $ é o viés do neurônio;
\- $ f $ é uma função de ativação como ReLU, Sigmoid ou Tanh;
\- $ a^{\[c\]}\_1 $ é a ativação resultante (chamamos de ativação o resultado da função `f`).

## Representação em Camadas

A estrutura geral de uma rede com múltiplas camadas envolve operações matriciais. A imagem abaixo mostra `c` camadas com `n` neurônios:

[![example](https://i.imgur.com/YWW20Sv.png)](https://i.imgur.com/YWW20Sv.png)

Podemos empilhar os vetores de pesos transpostos horizontalmente para formar uma **matriz de pesos** $ W^{\[c\]} $, e representar a inferência de uma camada inteira com múltiplos neurônios como:

Z\[c\]=W\[c\]⋅a\[c−1\]+b\[c\]A\[c\]=f(Z\[c\])Z\[c\]=W\[c\]⋅a\[c−1\]+b\[c\]A\[c\]=f(Z\[c\])

## Transposição e Organização

A multiplicação matricial requer que os vetores de pesos dos neurônios sejam transpostos. Cada linha da matriz $ \\mathbf{W}^{\[c\]}$ representa os pesos de um neurônio:

[![transposição](https://i.imgur.com/Z1PTZbY.png)](https://i.imgur.com/Z1PTZbY.png)

Após empilhar os vetores de forma apropriada, obtemos:

[![transposição de canadas](https://i.imgur.com/y0JFEPH.png)](https://i.imgur.com/y0JFEPH.png)

Essa organização facilita o cálculo paralelo das ativações em cada camada, otimizando o processo computacional.

## Ativação

A ReLU (Rectified Linear Unit) é uma das funções de ativação mais utilizadas em redes neurais modernas por sua simplicidade e eficiência computacional. Ela transforma a entrada de um neurônio de forma que apenas valores positivos sejam mantidos, enquanto valores negativos são convertidos para zero. Matematicamente, a ReLU é definida como f(x)=max(0,x)f(x)=max(0,x) Isso significa que, se a entrada xx for positiva, ela é mantida; caso contrário, o resultado é zero. Essa função introduz uma não-linearidade que permite à rede aprender representações complexas dos dados, ao mesmo tempo em que evita o problema do gradiente desvanecente que afeta outras funções como a sigmoid ou tanh. Além disso, a ReLU é computacionalmente eficiente, pois envolve apenas uma operação de comparação.

[![ativacao](https://i.imgur.com/vw4Vfos.png)](https://i.imgur.com/vw4Vfos.png)

## Resumo do Fluxo de Inferência

1. **Entrada**: Fornece o vetor $ \\mathbf{x} $ à primeira camada.
2. **Camada oculta**:
3. Calcula z\[c\]=W\[c\]⋅a\[c−1\]+b\[c\]z\[c\]=W\[c\]⋅a\[c−1\]+b\[c\]
4. Aplica função de ativação: a\[c\]=f(z\[c\])a\[c\]=f(z\[c\])
5. **Saída**: Após a última camada, obtemos o resultado final da rede.

Caso tenha mais interesse e deseje entender mais sobre o funcionamento de redes neurais, é recomendado a série de vídeos do canal [3Blue 1Brown](https://youtu.be/aircAruvnKk?si=_Mqrsn5WaLOiuHbR)

## 🧾 Formato da Entrada

Para este trabalho, você não deve se preocupar com **BIAS**, ele não será utilizados, você receberá apenas os pesos da rede. A entrada será uma única string contendo **três blocos** concatenados com `\n`, no seguinte formato:

1. A primeira linha representa a arquitetura da rede, em que cada inteiro indica a quantidade de neurônios naquela camada — por exemplo: `4,10,20,3`.
2. A segunda linha é o JSON com os pesos da rede (não há espaços, somente os caracteres especiais do json: `[`, `]`, `{`. `}`, `"`, `"`, `,`).
3. A terceira linha é a entrada da rede — 4 inteiros, ou seja, os valores convertidos para mílimetro, separados por vírgula.

### Exemplo:

```
4,10,20,3
{"l1":[[...]],"l2":[[...]],"l3":[[...]]}
55,42,14,2

```

⚠️ ATENÇÃO

O três pontos `[...]` representam os pesos da rede neural. Eles serão uma lista de listas de inteiros `[[12,-34,-127,-37],[-48,-54,73,127],...]`. Repare que elas serão uma string, dessa forma você deve fazer o parse delas para um matriz de inteiros.

## 🧾 Tratamento dos números

Em uma rede neural, é comum que os números sejam representados como ponto flutuante. No entanto, para este trabalho, o modelo passou por um processo de [quantização](https://huggingface.co/docs/optimum/en/concept_guides/quantization), onde os números foram convertidos para inteiros de 8 bits, o que reduz a memória necessária e simplifica o trabalho. Você pode notar que todos os números estão entre `-127` e `128`.

É necessário que você trate esses números como inteiros de 8 bits ao longo de todo o processo.

## 🧠 Tarefa

Implemente em Assembly RISC-V o processo completo de inferência da rede:

1. **Multiplicação Matricial:** Multiplique os vetores pela matriz de pesos camada por camada.
2. **ReLU:** Aplique a ReLU conforme descrito para cada rede. (A ReLU é uma função de ativação que transforma valores negativos em zero, mantendo os positivos inalterados.)
3. Exemplo: `ReLU(x) = max(0, x)`.
4. **Argmax:** Após a última camada, encontre o índice com o maior valor para identificar a classe da flor (0, 1 ou 2). Esse será o resultado final.

## Exemplos

Exemplo Entrada 1

- 4,8,15,3
- {"l1": \[\[-72, 6, 127, 117\], \[89, 115, -128, -79\], \[-83, -56, 127, -54\], \[-48, -128, 104, 98\], \[78, 57, -30, -128\], \[-41, -59, 47, 127\], \[-128, -29, 36, -45\], \[-128, 0, -61, 18\]\], "l2": \[\[17, -59, 39, 54, -67, 127, -37, -39\], \[0, -110, 122, -87, 44, -128, 79, -124\], \[57, -8, -82, 61, 127, -119, -16, -36\], \[-58, -106, 91, -61, 19, -54, -35, -128\], \[-36, -88, -128, -83, -5, -57, -88, 116\], \[-99, 0, 118, -101, -128, -62, 30, 119\], \[91, -40, -123, -5, 127, 122, -48, 77\], \[82, 2, 127, -101, -108, -14, 4, -32\], \[-6, 53, 65, -64, -76, 127, -84, 100\], \[-57, -101, -97, -56, 72, 5, 127, 60\], \[-30, 127, 56, -93, 14, -84, 33, 42\], \[116, 1, 29, 127, 11, -16, 113, 80\], \[-128, 120, 69, -6, -101, 56, -41, -76\], \[120, -41, -79, -127, -102, 43, -89, 30\], \[-29, -53, 127, -57, 45, -8, -105, 44\]\], "l3": \[\[7, 8, -107, 0, -45, -24, -127, -17, -19, 12, 82, -98, 63, -39, 14\], \[-79, 1, 48, 58, -51, -42, 78, -62, -71, 47, 127, 11, -110, 80, 15\], \[50, -51, 48, -30, -65, 84, 124, 64, 57, -10, -128, 49, 50, 29, -49\]\]}
- 59,30,51,18
- **Saída Esperada**: **2**

Exemplo Entrada 2

- 4,30,20,10,3
- {"l1": \[\[-41, -127, 125, 44\], \[-22, -3, 21, 127\], \[-61, -81, 127, 11\], \[-128, -19, 65, 20\], \[-9, -11, 14, 127\], \[38, -114, 60, 127\], \[24, 55, -7, -128\], \[-45, -128, 120, 82\], \[-19, -126, 71, 127\], \[-8, -127, 78, 62\], \[-128, -56, 121, -41\], \[122, 49, -127, -102\], \[56, 87, -66, -128\], \[29, -82, 81, -128\], \[78, 102, -99, -128\], \[38, 118, -16, -128\], \[-34, -59, -127, 35\], \[-57, -128, 126, 95\], \[20, -101, 127, -72\], \[-128, -80, 126, -23\], \[48, -128, 33, 61\], \[-39, -128, 99, -46\], \[112, -25, -127, -127\], \[-69, -22, 42, -128\], \[-15, -11, 83, -128\], \[127, 49, -104, -128\], \[-128, 66, 77, 34\], \[118, -119, -40, -128\], \[-72, -18, 33, 127\], \[-35, 44, -128, -56\]\], "l2": \[\[81, 31, 127, 14, 68, -111, -93, -26, 58, 112, -95, -87, 23, 40, 74, 1, -114, -19, 74, -95, -32, 19, 113, -64, 50, -110, -20, 48, -104, 81\], \[-74, -38, -85, -65, 6, -40, 62, -18, -3, -40, -9, 84, 66, 5, 127, 62, -46, -55, -63, 57, -26, 33, -21, -8, -30, 0, 36, -15, 42, -28\], \[-98, 53, -33, -67, 37, -18, 57, 28, 10, -60, 41, -53, 31, -40, 127, -58, -89, 43, 42, -69, -101, 57, -69, 66, 31, -33, -87, -44, 42, -21\], \[-15, -11, -31, -31, -24, -41, 88, 10, -34, -5, -24, 63, 80, 53, 98, 89, -43, -39, 35, -2, -2, 47, 50, 15, 52, 22, -14, 127, 30, 46\], \[-84, -10, 26, -54, 15, -28, -74, 35, 52, -1, 88, 103, 8, 19, 75, -101, 8, 56, -24, 75, -111, 39, 127, 114, 67, 46, -19, -38, -127, -35\], \[99, 62, 76, 46, 84, -40, -12, -11, -32, 119, 127, 102, -63, 43, -106, -31, 71, 19, -24, -57, -58, -49, 120, 99, -34, 16, 23, 99, 70, 33\], \[-63, 20, -79, -33, -54, 55, 75, -5, 28, 33, 127, 3, -108, 109, -48, -76, -27, 41, -107, -48, 45, -37, -47, -15, 5, -54, -62, -44, 3, 34\], \[-76, 71, 47, -88, -79, 71, 13, -114, 116, -127, -91, -63, -41, -93, -87, 18, 55, -120, -128, -27, 105, 15, 15, 89, 35, 66, -77, 10, 58, 66\], \[-27, -18, -98, 24, 3, 7, -97, 88, 6, -27, -49, 125, -55, -114, -23, -91, 62, 123, 90, -89, 127, 27, 10, -25, -16, -19, -87, -118, 88, 34\], \[46, -33, 83, -81, -110, 67, -81, -83, -4, 64, 16, -81, 29, -88, 19, -52, 104, -50, -27, 12, 59, 111, 127, -112, -15, -2, -31, -106, 112, 94\], \[-111, -74, -34, -53, 58, 114, -5, -128, -51, 16, -12, 88, 11, 80, 9, 7, -76, -77, 112, -16, -6, 18, -94, 30, 114, 63, -8, 15, 63, -9\], \[-12, -101, -7, -57, 88, -25, 44, 109, 124, -22, -52, 12, 116, -112, -95, -120, 38, -128, -39, 8, -93, 107, -68, 97, 122, 5, -48, -105, -13, -54\], \[67, 28, 66, -72, -48, -1, 50, -58, -31, -109, -34, -90, -70, 1, 98, 104, 82, 48, -85, -81, 53, -21, 52, -63, 75, -94, 26, -127, 99, 82\], \[-94, -27, -59, 26, 35, 108, 103, -42, 53, -69, 96, 60, 97, -67, -114, -127, -102, 56, -112, 86, -83, 92, 48, -31, -57, -54, -102, 102, -44, 15\], \[-23, -31, -65, -39, -11, -12, 47, -78, -39, -65, -29, 74, 69, -29, 127, 14, 20, -72, -26, 33, -42, -6, -13, -8, -22, 52, 34, 24, -10, 1\], \[-90, 103, -4, -102, -14, 67, -54, -108, 30, -120, 72, 111, -42, -93, -84, 100, 56, -81, 41, -83, 127, 99, 6, -24, -102, 105, -81, 113, 95, 85\], \[113, 94, 69, -59, -20, -6, -2, 90, 76, 41, -39, 103, 62, -45, -58, -39, 29, 69, -101, 64, 85, -53, 127, 12, 26, -52, 41, 3, 102, -108\], \[39, 60, -109, -56, 6, 48, -26, -73, 66, 60, 93, -68, 90, -96, 37, -101, 105, -73, 33, -103, 76, -128, -118, -12, -45, -23, 64, -125, -105, 81\], \[102, -106, 43, 36, -3, -128, -83, 8, -26, 126, -104, 71, 32, -114, -43, 112, 120, -79, -2, -64, 10, -78, -125, 55, 89, -71, -83, 91, -96, 22\], \[7, 123, -13, 52, 25, 112, 45, 58, 55, 27, 62, -23, -39, 62, -49, 103, 12, 52, 65, 38, 23, -57, -66, 42, 3, 37, 23, -128, -13, 17\]\], "l3": \[\[-12, -99, -3, 126, -25, -20, 91, -14, -16, 100, 37, -112, 25, -79, 75, 27, -128, -101, 31, 80\], \[-7, -96, 15, 25, 94, 127, -28, -22, -81, -27, -38, -115, -123, 34, 11, 86, -111, -79, -99, -56\], \[8, 25, 14, 45, -6, 25, -34, 10, 12, 12, -73, -34, 54, 39, 76, -57, 0, 2, -17, -127\], \[64, 77, -38, -39, -101, 125, 51, 75, 78, 112, -128, 10, -112, 96, -10, -98, 100, -37, 30, 9\], \[0, -4, -26, -7, -36, 83, 16, 17, 2, 78, 127, 21, 75, 27, 50, 97, -73, 49, 63, -1\], \[62, -92, -36, -65, -23, -16, -41, 67, -21, -69, 26, -69, 20, -76, -94, 62, 63, -30, 34, 127\], \[-20, 127, 62, 28, -25, 25, -16, 4, -53, 56, 13, 5, 20, -58, 104, 42, -3, 29, -51, -52\], \[25, -128, 113, 14, -47, 58, 52, 37, -98, 46, 6, 88, -96, -70, 68, -96, 33, -114, 16, 89\], \[-9, 20, -9, -128, 18, 15, -12, 0, 21, -55, -19, -28, -27, 11, -47, 14, -31, 93, 57, 97\], \[126, -12, 86, -65, 61, 46, -50, -19, 27, 73, 43, 100, 41, 53, 14, -47, -127, -19, -116, 5\]\], "l4": \[\[-93, 18, 127, -58, -121, 17, 19, -71, -89, 33\], \[52, 8, -128, -47, 25, 14, 91, 28, -13, 7\], \[51, 90, -73, 36, -19, 118, -85, 32, 127, -59\]\]}
- 64,32,53,23
- **Saída Esperada**: 2

Important

- A inferência deve ser feita **inteiramente em Assembly RISC-V**.
- Documente claramente suas variáveis e registradores usados.

## 🏁 Entregáveis

- Código-fonte `.s` com comentários claros.
- O relatório descrevendo suas atividades e decisões, é necessário descrever cada função implementada, justificando a abordagem utilizada.
- O .report gerado pelo simulador, que pode ser encontrado [neste link](https://riscv-programming.org/ale/#select_url_content=TjRJZ3RnaGdsZ2RnK2dCd2djd0tZZ0Z3aEFHaEJBWndLZ0lCY0laUzRDQmpBSnlnVk14Q2pBUUhzN1NBQ1lBVlFDU2NBQktvQU5nbFIwY1BBSUpFUzVTbkFESzlScVFDK1BBR1owT1lIZ0IwUUFPZ0QwWURnQk1BcnVOUUVMaFltUXFrekFLd0tuak1OazV1UGdBWkRob0ljUUFsVkNEdFBRTWpVMHRyZTBkbkdnNFlHRlFhVWlnczcxOFFBRzUtZjB5WU1oNVZPUkNBRlI0QVhoTVFVam9JQUNOSWdBc09PREFhQUJZQUJpRzRDRGc2VkJ0VU9CeTdEdkZUTXBnS3JPcWMwaEhtdmxOeEFFWlREQjRBYlZPaGdIWlpBRm9EZ0Nacm5nQk9BRFpiZzVHUmdGMVpVNXVBTXdBMjRBVm1lc2xlNEo0RDB1dnpPQUE0aHJKNFZDYnM4Umg5SG5ELXA5Z1R4TG5pN3ZkNGJKTHJDLWpkWGlEUVNUb1k5YnZjRHRpN2lOQ1FEM25TbmdjRHE5c1NEN3JJWWJjeWJkNGZEbWZkQ1FLZUVUYVE5ZVg4aHRMbnJTYmtOQ1E5eFg5WGtpWlVOVlVLWlE4Zm5EOXZkam1kVGhyYnM5cFhjRGNUaFU4N3R6WkZEUmphRldkRFpUcVR3UVJ6NFhiWHM2d1lLUmxDQTdjOFpEbVpxUGp6QmZTZVBkVWNtMFJ6N3JyUHJxMGJkWGo4S1dHWlpjRHJJQVZ6ZGM4bnBMWkk2ZUVETWJTQVhIa3dDeTBiN242WFhiaTl5TVhxN2R6ZzRUbmt5S1NybzkyZlZEWGgyaWRMdTY5YVhhc1lxT1dxbmlEcytudVhLUnZQNDBhUmdhUm43dVVOc2ZDTzBIaFVQNndkVmJUVVo4LVpjQjBUTHhTSG5YNTdmajRlOWFBdE9Jd2JzOFM1K2dHektUbnFmb3dXcXZhcWwyU2FobEN6enVscVp3M0xXTXJQTm11YlBGS0JwNHUreUp5dW1Zcll1eUVKRGw4VGF5RU1IWUVnbVVKN3RHOTRndEJHN3d0MmpMbHZPQUxucnVkR2RnTy1iSXN5RzVIaXkzWmlxQ2FhNWtNcUxNZENicUZtY3J4NGhXOUV5dFJEWWRwOEhJSEZDem9odm02azRxQktHeUxKMDRITTZxN2hoKzNMT3ZDNUpZWjhIYmJqWno3ZHNXMkdBYXFZNFFzK21HbkpjZG5TdmNZSHp1QjFsNmdScXFNWFdYci1DS25KdWd4QTVVbTZxTHFpbG9vRWM4Y2FmS0tJRitqcWRhNW9lQjZpbUo1R3dxYUlEaUFDRnJuRGNxcVhMcUJhM0xxOWJCanAyR0xscHluUm1KM1l2bHBESjRnY2lsVVF4R3Ixa3FvSnNnT2tZQ1V4VUtObnFId0RnQ25VMm4xaTVMdk9XYk12cURMUm9TSUpMb1NsVzZUWmVYT1VCQUs2czJ6cUNhU2VMZVFsREtuWXB2TGZGb3F5VkpzcUNrQWN1ekFQc1J5WUphTnlYTktSbkppNVY2c1FjMDVBWmN4VVV2QzEzSTZHWDVZUmRuYjdsV1lXWExTSUlmYzlZVnF2T3haWENoclpJVnRHNURKeDM3MWgrYzZDdUtUWGlPYWNQblBaOG5scEd1Wm1SbHVrZlRqWnpPYVZkSjJtNURIVmZXMk9Za1RwelU2S29wSXdadTdHUjhHN3NzeUlLbmh5d1V5cnowS29qOXdGTnN5ZWtkUTZUN1hhQ3JseWp5MEZRbUpqNjdZRitiU2dDZnR5NmNWdHFzOTd2U3c4ZG9rMlNWNVJmRkxJMVFhdXE1Z0M5eVNUWk1aTHJtbHdFNFZUbG04Nm5rMnFHSEtJelo4VUZrN1luSmxHdUV6Ym1pTGxuaVNyWXR5UmwxcXhLT0hrWkJ4NHZDRm15a20yV29sSnRYK3V6ODRGNTM5d2ZzbEpZdnNKMHI1VEtLTGxpUHFZcmNuT3M4Qnp1dkhuNlF5WGdMclhDK0Z5SzdVOGkrOFdycGVsNzN5SjJqQm1uUnF4V3NJNnhERlU2cUlMem1XdmlWVXJ3N1NsZ1lseVB1Q1lCekQwRkp6TTRJSVB3QU4tbU5mTWZwVzUwbTZycWZlTElkSktSc2dPSGVlcGlwQXhCaHNYZ1d4N2hReGhtMWY0UzhpU1FKUGwtZTRkbzhSOFU1SkpQOEJzdVRqZzhrQkkyUEFjb3BoSGkrQXlPNTNKV2dOTE5DRTljSkZaaHN0MlV1eEp6cVkzSWpBck8zNFY2VjI0Y3lCMFR4S1kwUlpxQ1pHZ0RlR25Gamd4RmVwY1JnYUlRWUdVeVVsbEYtQ0lSMWFVMTVIWi1BTWRDR3hOb1Y1aFgyb0tmMlJwSEYwMWVtTFRzVHhCSWx4MHZLTjA4RFRnTHdEc25SR1JpTjcxdzNKS2JFSk5SNE5oakdZd0VmamNxOVZTc09Ca21NbEVTTXBHbU5lOTQ2WVl3VE1pUmFZVkRUNE9QR3JPcDlaWGlWMGlWck5pUm9CR1J3OFZoS3VScG13elRYRmhUNkI5Mm5HTytBTElXSnh6anVQMHZGYVJnaXBHeFNsQnljMmdUWDZ5UnJPM0FjWFZCUUptcWlaQWkzWk02Q25SbmRiQkNzUHlKSVBxZU42K1RqbTZTZkJCQ0V2VnNwRGxWSVNEMHVGa1RkVzJUWE9PRzRicjVtK2c1RGsyMEFwSDBCQU9QYVVrVDZyanBqQkVFYkk3cVJOTGxUR3MrNXpJTVFabHBRQnNpYVNpbmRPM1lNTDRwNDRNaEJDR0ZBbENRcTErZ2ZWYytUNm45T2pCdEJraWtiejR0MHJtZStFSWg0RGd4VzZXa204OVJzaTJyeFM2Qjh0empSc2xGSWM0aXQ0TVZTaDFhcWhEd1habDRwMVhVVXorUWZESXVHSWUxelNRZ1J2RFpESnVvSW9KZzdBQ1h1UER1cFBDR0ZKVkVBU0lsVG14T2hHaXBJT1J1cUJkOHpFRFRkTFNtNUU2OE1JNEZxN1JOa3hBeUNrUFprdUlXUElwQXJCU1pqeEw2LUVlMFd3VW5mc0k0VUhycnJZTGZINU9zWXo0b2FoUE9HUEtuVU1tdXBxczZFbWg4WmE5VkxwQlVFa3M0NEd2TEYtQXVwSU94TXczcDFFeUJrTlJySzdwaVowRWNDMzB4dEV5cmtWTk1hMHdaRnlNOGNETjA4RWxWTXJwVHB3dytYcFJLSEZOb1Z5OXZ4T1hFMWdpMTI5VjduNU95dVljSm9nN0tBcE1XYVB5U3NOQ2pCNTA1M1dpbExrRXVTRFl0YUJ0MGtQSmxoNUZaU3c2bitmNUVKc3pjUTdDNG9EQXlqWGVNRlE4eUJqMUFuY0lURU9XVnVrYW9EMlZGLWJrczhNNkN1K2w3UVZnMWtIUWtjVmUxMDI2MXFrbUZCdWRLcFRnbjVqNW9kTlYwSTFsenJsQlZVY3JZa2tsaVRkdXBDVERhMUprZmIyY040YkV6OUwyWmlQYXJzUDdYeWJ1R1V5ejVJR0xsNnFlYWNKYnNSUzA2ZXh1T0JvQ0hKc0JEVkQxQkVQeWtWVWk4TW1MOFVFYjFrbDVLVVhsbzM0Z21uMVJ4VHhzMUJtZ28rMUNCVUd6bmhyZDQtNXcxOHhvUTVEMUY0cGtBTVAxMm91S1NQNXQzY1N6V3ZQNUROQ1pwYWpiMVhWRW8yVHppRVFVME5SSUlIQ2orUlBYaTV5SVJwa2pkQ1BxRG5Wd3dwaTl4bzBUS0dTTG1EbjFMVmdwb0ppVlpMMVFyUm9YVmR0MnMyWjZSekZPQU5ma3k3TUlsRzR3Y0phS2NaZ1hadzhvbTYrVVVCbEI1eE9SUEU3a1didXAyelREek9WNkotVWJkMHF4TWJnaTQ1K1RxejNKclluN284VjNqSEtLNEsxNE9xSzhlZnhzNW5JUm1NVjhwNURKMk14Z1MydE82ejRQeHZITE5ZZ3lHNlN4YVdyU1JFSkNZSFM5VjRqR05XNVZrUm1NK0xSQU5Xa1RhRFR4cHA3Q3lOSjYyb2RVT05aYW9acVplTkVXdVZsSVZ1MWN4SkJkQnlsWU51bGlwbVd4Vjg2UWFtK2xGYzhtWFcwN1A5SDZaTXI2WlJQc2RYNmxOMFdreEtvaEg2VDFUN2FVQnVEaWp1c1RTUGd6VWFySWZZRjlGazRsZmg2cE1HVGVKclVQTlZJeUlsdExLYnJJb2t5aXVsR25nZFRlRWVNNmpLSzdncXFsWFNGbGFuUStsSXpHV2xzdzNneTdQVkUyYWJoUVQrQ3VjODZjbHhlK2pEenVrV3VNZDU1c2dha3k0TGI1MWcrQlVrenRxWThhWUFrbVNDVEUzeGUxcVFlejNMeEo2bnFjdEdTSmExc1NMMmg4S2FNZ1lacEdScktTQnF2NExWMWdWVzZaMEtsV2x6ck1jcnRFckNOd1ZhZlVwK2RnaUhMbGFoTkZPTGRZSE5nVzZralZhZmJtWVVrZVlhWlhRRmtJcGwtUXhIN2pjanYrbVA4bW5NREZXSHZabEhSdFBZdUQrT1NaMmdvaWtXNFZNd2NNNnRJb0dnWVFVN0cyVWNCYmNweUdheUlZY2VZaGFnS3BNUEcwSW1Nc2doQ0RNMDRhWVNFUEM3YW9CWEtib1VLOCs4OERHV1dhQ0VJUTY0S3prQisraTdjTTBJa1M4WXFyV3BCWHFSb29pMnljeWx1elVRd3RDYUlNMFUrZitEb0JrWElndTVLYmNmSWJpZzB3NkQrYXlWcy1DSkVmSUhZdDJSZURZZjYtR0h5NVlDbXFFY3l3TTZ3VlFGQzRNQUkxQ3pVc01OdWR3YkI2Y3RTcVNud1c0M1VwT21XT1NhZTV1ODhsWUNZZGtHcUhLTWt4c1YrSGtBeUl5MzgwNkVvYnNwSWtDbFNSNGFFa0UyOFcyRElIcWFCcVdnaW1obFNXaGdJYnVXMjUwNjZINmpoMm9DbW80Z0VsU3NDUEJlRVBLM2h4ZXVFaWtlYVp3UUNkd09PdUVIU25VU1VXcXJ5ayt3bzRpMEU2V2tLUXlhVW1JdUdCOEZrTk9Md2kwVHdjNHFTLWtaT0ZxclllUzA2QXhhdVBBcTYxc3FVaFNCOGxzYUJGNHlJaGNLdXBHUUVhR2dJWGFKVTk0cnEraS1hcXh5T0N1cVNsSW8yc2tJOGhvUDBVNjZHMklENEZFM1U5UnB3ektFYTFPZE1yU2hvbnFhZUZralJSNG5CYW9XU1FrRGlIc1Y0dDBmV0VSbmlxaWVzNFktaEQrZlk2WWpxcllNS2V4ZTR0eHk0SHdpdTJ4aGh4cUt1OFNMb1NHcGt1UlhNU1VCczVNMklieTRSV0J4NEdxNENmK2Z1dlVZdVBvMlNud0hxOFNNRXl4bXFBeERDeistR0U2WVV0RThhek04eXRDNjhhSVdxcjJSK3VrdWhvaDgrbk83bWxlc0V1eTRXY3BGQitZdEk2VTBHUVNMSXJ1NFNMSTVlRHVFSWt4a1lOay1ja09YK1BCYUlVaXRxNUVjY2ltamliT0g0dHlRT3c2Z3B4OGVCY1k3b0w2YkNUOHh1K3hzKzVZdXUxVWF5VXlXaDIwV1JIdVEwREktOEFrQTQ2YzBCdHAtb3F4OGVvWmFZYkNkeWhlTnNDTVdVN2ViKzJFSzRETWVVR1NucHZZSkViTy15M1lIY2Z3aGszQjJSaDYzaTllck9Oa2dXLThJQzBoeWNMaUFLMkVoeVhaZUJCbU91bzVEWVQ0M1doQjFtb3Mtb2dFdXhoZXl5bFdrbWYwMDBNaXhaQ3VKMnZlZ1NJcEVLYmEyNlNNeXNYOHJTN0NaRzlCalNxcC1vQ2VxSUdDKzU2QmlDdTBqMlM0aWE3WjZHaGU1NWYrVVpTVThHZEI5R29vK3BnVzNFNk03TUMrSDBtaHB1dFI1WVZNZ2VoZUxJZnM0eVdwTFJiWjh1OHVIVUlKR29XMExXc3VENjNXR3N4NE5vbUc0WUZVNDVlb0FhQkVPY2l4bXhFWmdvbUtFbWpwVzY5b1ErMTZHOFVrKzRrV20yYlo2S2dDaElBNkVXQmhONkc4MkJheSs1ZTZmK0NZYnhTQ2Q4WTUtb2RzenFWbXg0eW9pbXJDc2tHK3ZGMzBpODFVeTZnNjdlZGhWMDFjODU4S0RrNXVJcElCWkZkVTJHMHl3b25wdTVLWUk1S3hhNUI1UlpzbGJaZ0k2bVRtQ2Npb1NVRFpEa3ZjU090RWkwVEtCK1NFSzJONDBvZkZNRXdrYU9vcUpzTTBtc21Jd1lhUlZza3FrcWR3Z1d6dUJsQ00rY0Jva1NUYW4rVEdURzRKYzZZbER3RlVQQ3pSamM4aVJvbFNlcStZZlplb0RrK1lBazZjQnMwMmRsLUdKODdNVVpIKzE1Ym1MSVVVSDA3TVVVcVpZaURJU0NCSmNxaXNXRk1sYWVEQklwYThpS3VldWtEWnZZUEZsaTNCckpsSVFwWmxCYWZGcmFjbEY1SllncTNVeUlTQ0lDUTRJcUlhS3k3NTExTys2VUxDZDIxc2lrS2U4QklwalJvR3BLRFl5c1VvaTg3bGRLMXNYUi1vczJBbERZTVYrT1AySFVrU1JrWDhzS1ZNK011MGQwNk1rQkJLTHdxWno1QzZGYUkrdTB6a3Z1eUlya3BxMytaU0lwQXBxK3FWbFJMdzVPTm9MNnI4aUVPR3JHeDRMV09FMEdLZXQ1dElqQm9vWUVCbDlwS296SWRxM2k0YVZrdUVGZW5ZaDJIMi1HNDhYTzhJbGMrWkI4c2hGNjRsUjFibTdZZ1NNNm8yWUNBMWxsQ015V2dTbGNHeGlXYWVXQ29JdllqNmZrNGE3RWJWSzJ6TzVXdkVOVUNCd29KbTBSamwyRVU0dTBwMUp5ZitDV0RLWE9SNHA4ZFljY0N4SlkzRVVVV3FZQ2QwbVlycWx0N3RqNTZhK0lIcFRWOUZSeCtKK0lTR3lrNFY2TWZWeXVqbS1DU09wMGk4R1NBdFpKSHVVeVRSNjEyaFVzaG9jNUxvYTArc3pGSFV1aHJTUDArOHVJZkdKTUhLNllqODRZZjRRMUh3czRZQ2NvVWtCRW9ZNkNzOHFaYlpBcC1VVW9rc3YrYWU1MUNpZjUyRWNFWWNob3pLbEliSUxoMWxXNmFHaCtYNXJtLW9hODlLYXB2cGR3TGNwMGNFZ0NHRTRxYnRVRkJGRWg1cTFzYk5UZTVZM1NvSUhZaENLNFFVcDBKc3VxbEZGTklwZWx1RTdHS1o1dEx3V3N6S3JhN09YaytwTHBIdzJDYjIwSStwUk5naWtXTGNJZXFzNDJ2bUVtSzlURTY2SkpCdGw5S3VacUhlUHBMTzZZN0NXMVlaaEcxcW9JZmtHK2FZa0V1YzROZitUQnU5TUlmSW1ZbnArY3lNLVJLdVBNUWtvWkFwYUctMWFvQ0RPOUpZdE5CODhObERLWW1oSU5TaFJ5TzJ1K1p1OFVjVVBENnVBaTMyNnA1bEc4a0NUS2JPeWFkR1Z5T2hjdFN1RlVieCtpa1lreFNPTzVTRGpEQ00xb1BCN2grOHJKU2Q2WVlsNjJEMnBkSXlyRWNvblVVb2oyZnRtTkI4MUsyeVR3LTRtNDZxQjlRVHBGMkVqNmhDa3h1dW80cEkxVTM5WEJnaWo2SlNLNDUrYlZkeFA5RWN4ZEJhRmRiK1lUSE9CREVUS1lhWURNWkJiNXNLQXkyU01aT21QVlM4anlhZUIrNEt0ZGptYWVWTlJ0SHcrcFhtb0lHNURseTh3cVY5YmxvSXFaOURXU3AwRTVsSU5ZK2NmVW1oMlVTQ002b1lsK2YrRTYzVW9lcUI0WWtzellEcS04dWxhMm1ockNrczJDeW95TWlpbm0zUis2RFYrWTJ5ZTBFMG4xQ0VMdEI4UzRTT2dZcUt3b1pKWVJRQ3ErT3hvamRPUGV1a1NDVllVSk1EeFdybGlzMVdUMW1VMXNMNkpLREVtekt1VzBqRjk1c0t5dUNabHlTYy1HU1pYT1AwclNhb010VlZhb0FhcUNlb2ZzSU5hSXo4U3NBaHJRTFV0QzBkTFR3YStJajZVSTVSREpHakZkNE90OXpHU0JqKzY1c3QzaWx5STlTcVdTU1JHOHZKeEZpcHE5UWNqbCtGOUMrNWZGbElVVVlwZ05BSytMekNvZGFEM2lEbzJDVzBFcW4xbVdRQlJDUEpXNnpkS1lHdGFUTjhQa2tScnQwc2dGVzYrdDRrNHIrbEN0a0xBSkRjZHpsNTk5cmxyMFdTU01TSjBMWkxmRzRUMXNKOFhzdjVQTGZMSGpEWVZMSWMwWXp6QVVuY0syZXhoai0rMVlJTkR3UTY2dENMZDlWUzhkZis0VnFaNGFSRWVlYnh6T0lFSnAzaWtHRXFZQ1ZEVWJMb2xwVjVrTlgwZzB2eE45QXBtSmZ3NEorTnZCanRlbzVFOFU5WTlzMjBkR0xpSk52RkxMSnVoMWFlRWl2dG9OYm80YTBCRHlNQzV4ZlZHakxvTGNQNnJiRDFmKzVXemszYVhLb3J2K3NLWVNSb2ZtenpQb1FHNkY2dVJ4K0ZoamFJMlVZRWVVcElLZVo4Z2g0Z3dobDgxN1lqRTJMSVU1MHNhb011czR5YkVvRk8zQlg2MEJ2WUVOUHBFVUdoVkZyU3JhczFlcE5SV2swQnhocXdwaFlNcEFCQXV3cHdXd0E0V3dIWWxDc2dXd0xZWkNaaFBBRUFkQU5BUFF1SEZ3T0FwVWlTZWE5SEpJOVN6SFNJY2JpU3BVN0hPQWo1WEhHSUxZM3dHSE1BTkE0Z3JnUEE5UUhRM1E0Z2ZRUEFxQUFBSHFRS2dEQURZRGh3b0c0TW9GUU9vQXdFd0hzREFEd0FaendLRE8wSFlIa0Z3RHdBQUJRQUNVZW5obmRuUEFCQWRnVWdkQTFucXc5bmhucEFQUUpBWmdkZ1VBdXdPUUFBN2p3RUlLSUJJTTV4WjZZSkoxMEwwQndLWUZaMjUrNXp3STRMd05NSEVQNTZnRUYyRUJFTkVMRUZ3S1FLNS00SWx6d0o1OTU1VURrSGtBVUZVR1lBZ0hZQVFEMEJaNmwzbC1GK1VQcDRseVZ3UUdZUGgzQUxBRFY3d0MwT2NOSFhHLStTbUNacGpqVnZSaVppbmVON05Hd3kzZWVQRXZ2R2lZUWhaSGUyelcxbnlIdENrMkxwVld6TFJWa3MyQWhuV0NacEVwUWRJeHR4bTFGQ1pycm91RWhoWkFXa093WlBFbExNclZaYTFpWmdOaVhpYnU5Ny11dklQRmQ0RTZCaGpITWdsKzUrMTUxK0RBY04xekFMMTNSOFdFTjNSbytPZC1POE4yTGdXdHRNT3Q3RjIzM29UWFNMTjhqK0F3dHdhbHlJcmtqOXRHc3R0LWN5Z1lJcVQxdDVOeTNkRFhCOEJsdXFqeWQtWll5UDkxOVRhY2Z0OTB6NzFTbUY4VUl2RCtlR0ZQdVZNbS1sbkVKNFYyMTE1eDE1UWxEekQtMTZjUGRLbTJ3bDhZTjgzRWQxajB0ZEhRdkhULWp3ejE1YXMwcGhUeGQ1cnhwTmQxejhJbnlIaWptOUNHcnl1QUd2WEJ6MHRDSGxrbDdUZ1VkNUw2MTZEekwrRDZRQUNQTDNZSDEyY0ZMMFZ3WjlySHRHSkptTDhLSDJIMHIyTi1LaG1qSDk3M0gtOVM5d0NaekxIMFY5ckRXQWtkenpnRm40bDlyQ2lsVXhvb1grNTBydzZxbVFiK1gtWjlyQTZyVHdYeW45bjROd3BwcjdYM1owcjdycUtzTDhuMkg0WjlyTy1aYjJkRjc3WDJEMTF4d0VIN2gySk83VWhocVRQNE05S0lRaHFYUDA1a3lDRC1aK1B4RDNBSlA4SHdraE9RWk83WXRZTXd2OHYrMVZpejhCdjNaMXY2UVBjRHYxUC0xMHZ5dnhPV2Y0ZjA1cGYyUDc3NlItZjN2eDM0WndLSC13TTVsaEFCcWtFQVFBT2I2SmNNUUlBNEFSQVBjNVFEWUI5bmVBZjN3TTdnRGtCS1lXdnFQd1FGZzhldVFmSER2MXh2NGpCQStwQVdRRGYwaDQ0RGlCeFhMLXVERHY3a0NTQlZBLTNrUU8rQ2Y5dk91LVhybmdMT0FFQ2YrZEE3em9SeTRHVUNlQjFBdmdUZndENjc4bUJDQTVnUjExODVtQUlBTmdHd0hBQ1U1a0FJdUNBdXpxWUFBRENoZ0JBRkFERTc1QXNncGdKdm1nTGdETkFBQWZMWnpRRThCR3UzQU13Tk1IY0RjQUN1eWcrenRNRklDTEI5T1lQTkFEa0FZQTBBNEFtUWRnRm9MbUFLRDh1Vm5Pd1dnSjBDVzU3QkJuWUFIb0dnRGlBNEFxQUtqdUlBQUNlSndFenFnQjRCYUJhK3pYQkFjbHg0QmJBQ0FVUFdZUEoybjRNY2NBQW9Gc0dZQUlCNWNMTzFuWXdUd0FBQ3lFQVR6bFlJb0EyQkRBVlFtNENzVE1BZ2dNaFJYVUdCd0VjQm1CeEFIQVpBQlp3QUFHQUFPWEJnNGRZQStRbmdBQUJKZ0FPUXZJUXB5MEREQ3JPdGZYUU9ad3M1WkQ5T0xRRVlDVUd5RThBQUFQTmtJbUdMRDVPLVE1VHNnRTg1N0NZQUFBYWh1RTJkb1lZUXBMdURHeUZUQ0ZPNlhiRHFjTHc1ZTgwQlBRdm9RTUtHSERDQWdLbkJUaWNEbUhBajhoeXdyb2NnS3lFRUFJQTdBZElMc0ZjSGd4cUE4SWhBT2tBczRRaUZPMEktdm44TlFEOURCaEl3Mm9EVUlBQUtJUUFBS0txQU1BS3dxLW9seTJFdkNXZ09RdkRtOFBrNC1Ea0I2d2x6bGtLZ0JOQmRoUEFQemtjTGhFSWluQTV3bUFKY0o2QjdDb0Fkd2g0U0FMczZ3ajJnUkEzWU1NTG1GVWNhT3pJa0VheU84QWNCWUFFWFhBSEZ6U0grQTVoQUFLVlVBQUI1VVlXVVBhQ3dCa0FVQVhRUEVNeEhnd3JPK29tQUhNTUZIb2luQXB3S0FOOEZPQS1CTlIyb2dBT1E0QS1Sam80d1A0R0dHMGorK2NvdWdELXdWNDhBbFJ3QVYwZWtBOUZlaW1ReXc4TVdIenhFRWpBUmdnVVlTU1A0RDFBd1I4WStVZVFLaEZwanVoR3dYb2ZpSUJFakNUUmVZM01mbU5tR0Zpb3hyQW9QaVdKbEVlZGZlVWdtUVhJUDhGS0N6QmlYWVlmVUNjQktjZUFnZ0JnQVFDMkRnaVdST2dOb1hNTWxFSEF0QUZnRjBXaVBTQWlpeFJ5dy1RWDJNMzYrOWlBUW9tSVFBRWM3QWtRS0FLUUhpSHlDaHh2WXpjVVZ6SUJSamFCYlktdnRlT2pGQjhOeGw0OXpoRVB5QmdCVUF1LUU0SjhDK0FpUnZCU0FhWUhBRjBCMkFST09nbUFDY0FzNFFBY0FuUUd6azBCTUZnOGFBdFhVZ0lZQzhFYUNxT3FBU0NkQkpzNXBDbmhSWFZZYmhNTTQ0aXcrT0VvcmpoSWtFK2NvQVpnWFFMQUVpQlRBbkFEZ1lQb1FIaUVpY2VBaGd1Q2FZUDc0V0RQQVhFMDRINlA4RjBUSE80Z1VnSDZPK0JJaU94bEUtaWRZSVlrRUJTeGhuTEljZ0E2Q3pCZGd1d2tBVGFNczVnOHBCa2sraVVKSUlEZWpSSkFBUWgySFNpQ0pCbkxZV2VMSURzQ05KRWtvY1FKT2ttcmlyaGQ0dlFCc0s1Rk5BRGdFb280ZkFIOEV5UytSVW9qaVMrSVVreUNVaE53bG9GWkxNQmFUQkoySEpNYkpQYzRrVE54QVVwU1MwQXM3eFNVaEFBS204UTJjTEFsblR5VU9KdzV0Q0RnK0U0SVMxelFGY1NyQnVYYmdMeE9va3dCYUp5VWtTYnNHU25SVG5odkFUb0FNTTZDN0FTcGJnNlFQVUxtQmNTZ2hNSWw0VDBFSUE5QUFBUWkxTjJBUUFBdTBBWGdGMk5VQ1JBbE9OZ0VRSU5QcUFjQVJwSEFUb0JaMmFtclRaQXRRQm9FUktLNk9EbkJzWWdBT0tLVFVBQlk1S1RvQUFBaUhBQUxqQUFHRXlDZUE4UXlmblFHSzVEanpCWlUzZ1BvRU1EeUJGQTdnU2dISjNrNjVBZytsWFE0UkFCNEE5QnBndWdKb0hNSUM1VERycFpnZmdGRUJDQm1CNkFzUXBUaWFNNkJlQmNncEFCR1NFQXM0RFM2dUswbUNUb0dhRTNTN3BOZ0pvUHNDNkNYQlNwY1FVd0VZSXM2aWNvQU5BQUFOWmd6cEFxQUt6Z2NKY0JHQ3pBd3cydnJGSU00Q3lqT1NFbENmK1BRbVlTZUFNRXg0V1dLcUFWak14SXc4a1FBQTBTUjVJMVFmVUhKRVhTQ3huUVZzUWdJekZWamhoVVFTa2Z3QWFBRmlJQU9zb3Jsa0lVNVNBOGdNd01hV0ZJWUJnQnJPWlE5RWNlSXM1K2lReE1BSU1WUkswRktjWE9Gblk4YWdDTURzU0E1UmdReWEwRGk2N1M1Skx3cVNVSk4yQ2RCN1piQUoyUVFCZG41ZDNaLWdMMmRSS0VuU0JLaEljNm9ibkxEbCtBUUFWblNPUVozMmwwQjlPVnNyR1RNRjlFd0EzWkhzb01jMEJhQXh6UEFYZ0xVYlhMVG1leWlKSmhGUHJIelFCVUFFeFRnZTBhUUdNa1d5WGg1QXl5YjczSGw0ZHdZYkk5emxrT2JIWWN4SkxBb1Btd09ubWtCWjU5bkxrU3B5WmxPQmNPRzh1emh5TXM1Y2psSkVvdzRRMkFsRytUcFp5QXFZVHZJNjQxYzZ1Rm5Pb1EwTjBBREN1QWo4K29UMEVhRXFjV2hObk5LVS1NLWt2eU9BYjg4ZWZaSjZBcFNSZ1pnWjRNWEpMbXBEYStzSTVjYnZQNjVpQ1paNVEtNFlTTk1BM3lhQVRnREFIRjFyNTZ6Q1JtQ3B3QVZNUzZIek5oWThua2FmS09HRUtPdWpnVVVWY0o4bjNDLUpWNGhCWGZOcTcxY1BSMFBYQVJ3cHNDM3lreGNJQmVicE9vVjhMdmdNQ29XWFp6TG42Y0I1TWtvcVlaeHdrNFNtSkxFNENhQk9CblRUWnBNd0JhWFZ5V21FejFwTFUyUUhDS0VranlvNVUwdWdCMEhpRkRTN0F1Z1hRTklER2tUVGp4a3NscWRJSk1VUUF6RkZpcXhTNXlJbndLaEo1aXl4ZFlzWkVaY0pPQ25VZ09TSkU2MkJzNVZuTXdNcDB5Q3pBTE8raTRlUnYwOFZ6VHZGYmk5TGtGMzRDd0JTQThJT1FFNHJ0RlVkVEZTUzZRR1lFNkR4Q2xPSVFDNFo1eDRBM0NIT3MwLUpYUUVLWEZMVUFwU3VoVDBDSW14S1pnTlNzb2VESHRHcEwwbG1TN0paQk95VTFLck9lQkZwV29wc0R0S0NBblMySlRVdGtDNUxuRjdTb3BTVXJLWE5LRXVzZkxJZmpPR211TGZGbEhXeGJ3SG9EeENtQUhBTW9YWUU2Q2tBK2hQQ3RBSW9MOUdxQVJBY2dCZXE4QURGVktzNVl5elpiVXM2QXZLUEYtVXdhVmt0TVc3QnZsemlxaVlrQzZYQmNlbGZ5dTBlc3NHVWZMZUE2eXNRQVVKYURyTFFWWmdTQUFnSFduVkQ0NXlFMVFKYU5GRVdjZVE0U3BBRFlBeFZVZDh1MG9QMFNNQ0RIaExXNS1vb01Tc3BUNFNMamhRWGJSYWNGbVV1S2ZGTWdNR1lOSmhVaUtFdU9Fd0xoSnlrNHhkWE91QUVBSlVHb25JQk1Bb0FEZ0V3RXE0RUF4VlFxcklDS3U2NXdpNUFtQVpJWGdHRlZRQmtBQ3FpQUtvT1ZWMEE3QXFBVlZYS3ZWV2FxTHBPcXZWUWFwZ0R5cVNBRUFBQUdLbXI5VnNxaTFVYXF0V0NBN1Y1cXkxWENKcUd1cUhWN3FpQUtvQzlWcXFOVlZxLWdGNnVVNWRCSEExQWZvRFIxeURNek9nSEFlVGw2dktIVUJ5QUxNeEFHM045bHdBQUFicEVEMVVzQVJnOG5TNE5hc0xXRnJ0VmVBZEpVQk9tQjdpcGdGQU5BQ3dDN0FnQXRBZUFBZ1BFTm9DUkJ4QTBxakFNQUFiVWdCWmdHYTIrV0txMEFEcWdBQQ==).

Important

- A nota será atribuida pelo relatório, o `.report` será utilizado apenas para validação da solução.
- O relatório deve ser entregue em `.pdf`, você pode utilizar `markdown` para facilitar a escrita/estruturação.
- Utilize seções para com # para descrever cada função/etapa do código.
- utilize \`\`\`s seu código aqui\`\`\` para apresentar a implementação realizada.

Back to top
