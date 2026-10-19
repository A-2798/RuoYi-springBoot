# 阶段一：Maven 打包后端
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build

# 使用国内镜像加速依赖下载
COPY docker/maven-settings.xml /root/.m2/settings.xml

COPY pom.xml .
COPY ruoyi-admin/pom.xml ruoyi-admin/
COPY ruoyi-common/pom.xml ruoyi-common/
COPY ruoyi-framework/pom.xml ruoyi-framework/
COPY ruoyi-system/pom.xml ruoyi-system/
COPY ruoyi-quartz/pom.xml ruoyi-quartz/
COPY ruoyi-generator/pom.xml ruoyi-generator/

# 先解析依赖，利用 Docker 层缓存
RUN mvn -B -pl ruoyi-admin -am dependency:go-offline -DskipTests || true

COPY ruoyi-admin ruoyi-admin
COPY ruoyi-common ruoyi-common
COPY ruoyi-framework ruoyi-framework
COPY ruoyi-system ruoyi-system
COPY ruoyi-quartz ruoyi-quartz
COPY ruoyi-generator ruoyi-generator

RUN mvn -B -pl ruoyi-admin -am clean package -DskipTests

# 阶段二：运行镜像
FROM eclipse-temurin:17-jre
WORKDIR /app

ENV TZ=Asia/Shanghai \
    JAVA_OPTS="-Xms256m -Xmx512m" \
    SERVER_PORT=8080 \
    RUOYI_PROFILE=/home/ruoyi/uploadPath

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && mkdir -p /home/ruoyi/uploadPath \
    && groupadd -r ruoyi && useradd -r -g ruoyi ruoyi \
    && chown -R ruoyi:ruoyi /app /home/ruoyi

COPY --from=build /build/ruoyi-admin/target/ruoyi-admin.jar /app/app.jar
RUN chown ruoyi:ruoyi /app/app.jar

USER ruoyi
EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dserver.port=${SERVER_PORT} -Druoyi.profile=${RUOYI_PROFILE} -jar /app/app.jar"]
