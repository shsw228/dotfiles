export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export JAVA_HOME=`/usr/libexec/java_home -v "1.8"`
PATH=$JAVA_HOME/bin:$PATH
eval "$(gh completion -s zsh)"
