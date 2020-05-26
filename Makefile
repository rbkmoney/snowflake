REBAR = rebar3
ERL ?= erl
APP := snowflake

.PHONY: deps test dialyzer clean distclean

all: deps
	@$(REBAR) as strict compile

deps:
	@$(REBAR) get-deps

clean:
	@$(REBAR) clean

distclean: clean
	rm -rf ./_build

docs:
	@$(REBAR) edoc

test:
	@$(REBAR) as test,strict do eunit,ct

dialyzer:
	@$(REBAR) dialyzer

xref:
	@$(REBAR) xref

typer: 
	typer src

full: all test dialyzer typer
