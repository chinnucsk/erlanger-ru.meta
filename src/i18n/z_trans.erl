%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @doc Translate english sentences into other languages
%% @seealso GNU gettext

%% Copyright 2009 Marc Worrell
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(z_trans).
-author("Marc Worrell <marc@worrell.nl>").

-export([
    translations/2,
    parse_translations/1,
    trans/2, 
    default_language/1, 
    is_language/1, 
    language_list/1,
    lc2/1, 
    lc2descr/1
]).

-include_lib("zotonic.hrl").


%% @doc Fetch all translations for the given string.
%% @spec translations(From, Context) -> #trans{} | binary()
translations({trans, Tr0} = Trans0, Context) ->
    {en, From} = proplists:lookup(en, Tr0),
    case translations(From, Context) of
        {trans, Tr1} -> merge_trs(Tr0, Tr1);
        _ -> Trans0
    end;
translations(From, Context) when is_binary(From) ->
    case ets:lookup(z_trans_server:table(Context), From) of
        [] -> From;
        [{_, Trans}] -> {trans, Trans}
    end;
translations(From, Context) ->
    translations(z_convert:to_binary(From), Context).

    merge_trs([], Acc) ->
        Acc;
    merge_trs([{Lang,_} = LT|Rest], Acc) ->
        case proplists:is_defined(Lang, Acc) of
            true -> merge_trs(Rest, Acc);
            false -> merge_trs(Rest, [LT|Acc])
        end.

%% @doc Prepare a translations table based on all .po files in the active modules.
parse_translations(Context) ->
    Mods = z_module_indexer:translations(Context),
    build_index(parse_mod_trans(Mods, []), dict:new()).

    %% @doc Parse all .po files. Results in a dict {label, [iso_code,trans]}
    parse_mod_trans([], Acc) ->
        lists:reverse(Acc);
    parse_mod_trans([{_Module, {_Dir, Trans}}|Rest], Acc) ->
        Acc1 = parse_trans(Trans, Acc),
        parse_mod_trans(Rest, Acc1).
    
    parse_trans([], Acc) ->
        Acc;
    parse_trans([{Lang,File}|Rest], Acc) ->
        parse_trans(Rest, [{Lang, z_gettext:parse_po(File)}|Acc]).
    
    build_index([], Dict) ->
        Dict;
    build_index([{Lang, Labels}|Rest], Dict) ->
        build_index(Rest, add_labels(Lang, Labels, Dict)).
    
    add_labels(_Lang, [], Dict) ->
        Dict;
    add_labels(Lang, [{header,_}|Rest],Dict) ->
        add_labels(Lang, Rest,Dict);
    add_labels(Lang, [{Label,Trans}|Rest], Dict) ->
        LabelB = list_to_binary(Label),
        case dict:find(LabelB, Dict) of
            {ok, Ts} ->
                case proplists:get_value(Lang, Ts) of
                    undefined -> add_labels(Lang, Rest, dict:store(LabelB, [{Lang,list_to_binary(Trans)}|Ts]));
                    _PrevTrans -> add_labels(Lang, Rest, Dict)
                end;
            error -> 
                add_labels(Lang, Rest, dict:store(LabelB,[{Lang,list_to_binary(Trans)}],Dict))
        end.
            


%% @doc translate a string or trans record into another language
%% @spec trans(From, Language) -> String
%%   From = #trans{} | String
%%   Language = atom()
trans(Text, Context) ->
    trans(Text, Context#context.language, Context).

trans({trans, Tr0}, Language, Context) ->
    {en, Text} = proplists:lookup(en, Tr0),
    case translations(Text, Context) of
        {trans, Tr} ->
            case proplists:get_value(Language, Tr) of
                undefined -> proplists:get_value(Language, Tr0, Text);
                Translated -> Translated
            end;
        _ ->
            proplists:get_value(Language, Tr0, Text)
    end;
trans(Text, Language, Context) ->
    case translations(Text, Context) of
        {trans, Tr} ->
            proplists:get_value(Language, Tr, Text);
        _ -> Text
    end.


%% @doc Return the configured default language for this server
default_language(Context) ->
    z_convert:to_atom(m_config:get_value(i18n, language, en, Context)).


%% @doc Return the list of languages selected for this site
%% @todo Make this configurable
language_list(_Context) ->
    [ en, nl ].

%% @doc check if the two letter code is a valid language
%% @spec is_language(LanguageString) -> bool()
%%   LanguageString = string()
is_language(LanguageString) ->
	Language = iso639:lc2lang(LanguageString),
	Language /= "".
	

%% @doc Translate a language to an atom, fail when unknown language
%% @spec lc2(LanguageString) -> Language
%%  LanguageString = string()
%%  Language = atom()
lc2(LanguageString) ->
	true = is_language(iso639:lc2lang(LanguageString)),
	list_to_atom(LanguageString).


%% @doc Return a descriptive (english) string for the language
%% @spec lc2descr(Language) -> Descr
%%  Language = atom()
%%  Descr = list()
lc2descr(Language) ->
	iso639:lc2lang(atom_to_list(Language)).
