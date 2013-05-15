
%% @author Rubber Cthulhu <rubber.cthulhu@gmail.com>
%% @doc <em>uintvar</em> - enconding and decoding API for
%% variable-length unsigned integer (or simply uintvar).
-module(uintvar).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-export([encode/2, encode/1, encode32/1]).
-export([decode/2, decode/1, decode32/1]).

-define(UINTVAR32_MAX_SIZE, 5).

-spec encode(Max, Value) -> {ok, Octets} | {error, badard} when
      Max :: pos_integer() | infinity,
      Value :: non_neg_integer(),
      Octets :: binary().

%% @doc Encodes unsigned integer <u>Value</u> into binary <u>Octets</u> with uintvar format.
%% The encoded value must be <u>Max</u> bytes size or less.
%% If <u>Max</u> is infinity then entire value is encoded regardless of dimension.
%% Returns <u>{ok, Octets}</u> in success case.
%% If encoded value requires more then <u>Max</u> bytes then <u>{error, badarg}</u> is returned.
encode(Max, Value) 
  when (Max =:= infinity) or (is_integer(Max) and (Max > 0)), is_integer(Value), Value >= 0 ->
    encode(<<>>, Max, Value).

-spec encode(Value) -> {ok, Octets} | {error, badarg} when
      Value :: non_neg_integer(),
      Octets :: binary().

%% @doc Is equal to <u>encode(infinity, Value)</u>.
encode(Value) ->
    encode(infinity, Value).

-spec encode32(Value) -> {ok, Octets} | {error, badarg} when
      Value :: non_neg_integer(),
      Octets :: binary().

%% @doc Encodes 32bit unsigned integer into binary with uintvar format.
%% The size of encoded uint32 is 5 bytes or less. So calling <u>encode32(Value)</u> is equal to <u>encode(5, Value)</u>.
encode32(Value) ->
    encode(?UINTVAR32_MAX_SIZE, Value).

encode(<<>>, Max, Value) ->
    encode_helper(0, <<>>, Max, Value);
encode(Acc, _, Value) when Value == 0 ->
    {ok, Acc};
encode(Acc, Max, Value) ->
    encode_helper(1, Acc, Max, Value).

encode_helper(Bit, Acc, Max, Value) when Max =:= infinity; is_integer(Max), Max > 0 ->
    Octet = Value band 16#7f,
    <<_:1, Val:7>> = <<Octet:8>>,
    Acc1 = <<Bit:1, Val:7, Acc/bytes>>,
    Max1 = maybe_decrease(Max),
    Value1 = Value bsr 7,
    encode(Acc1, Max1, Value1);
encode_helper(_, _, _, _) ->
    {error, badarg}.

-ifdef(TEST).
encode_test_() ->
    [
     ?_test({ok, <<16#00>>} = encode(16#00)),
     ?_test({ok, <<16#7f>>} = encode(16#7f)),
     ?_test({ok, <<16#81, 16#00>>} = encode(16#80)),
     ?_test({ok, <<16#c0, 16#00>>} = encode(16#2000)),
     ?_test({ok, <<16#ff, 16#7f>>} = encode(16#3fff)),
     ?_test({ok, <<16#81, 16#80, 16#00>>} = encode(16#4000)),
     ?_test({ok, <<16#ff, 16#ff, 16#7f>>} = encode(16#1fffff)),
     ?_test({ok, <<16#81, 16#80, 16#80, 16#00>>} = encode(16#200000)),
     ?_test({ok, <<16#c0, 16#80, 16#80, 16#00>>} = encode(16#08000000)),
     ?_test({ok, <<16#ff, 16#ff, 16#ff, 16#7f>>} = encode(16#0fffffff)),
     ?_test({ok, <<16#8f, 16#ff, 16#ff, 16#ff, 16#7f>>} = encode(16#ffffffff)),
     ?_test({error, badarg} = encode32(16#ffffffffff))
    ].
-endif.

-spec decode(Max, Octets) -> {ok, Value, Rest} | {error, badarg} when
      Max :: pos_integer() | infinity,
      Octets :: binary(),
      Value :: non_neg_integer(),
      Rest :: binary().

%% @doc Decodes <u>Octets</u> as uintvar value into unsigned integer.
%% <u>Max</u> is maximum number of bytes which is processed by the function to decode single uintvar value.
%% If <u>Max</u> is infinity then decoding continues until entire single uintvar value 
%% is extracted or all bytes of <u>Octets</u> is processed.
%% If uintvar value is decoded successfully then returns <u>{ok, Value, Rest}</u> 
%% where <u>Value</u> is decoded unsigned integer and <u>Rest</u> is the rest of <u>Octets</u> after encoded uintvar.
%% Otherwise if first <u>Max</u> bytes of <u>Octets</u> do not contain entire uintvar value <u>{error, badarg}</u> is returned.
decode(Max, Octets) 
  when (Max =:= infinity) or (is_integer(Max) and (Max > 0)), is_binary(Octets) ->
    decode(0, Max, Octets).

-spec decode(Octets) -> {ok, Value, Rest} | {error, badarg} when
      Octets :: binary(),
      Value :: non_neg_integer(),
      Rest :: binary().

%% @doc Is equal to <u>decode(infinity, Octets)</u>.
decode(Octets) ->
    decode(infinity, Octets).

-spec decode32(Octets) -> {ok, Value, Rest} | {error, badarg} when
      Octets :: binary(),
      Value :: non_neg_integer(),
      Rest :: binary().

%% @doc Decodes uintvar binary <u>Octets</u> into 32bit unsigned integer.
%% The size of encoded uint32 is 5 bytes or less. So calling <u>decode32(Octets)</u> 
%% is equal to <u>decode(5, Octets)</u>.
decode32(Octets) ->
    decode(?UINTVAR32_MAX_SIZE, Octets).

decode(Acc, Max, <<1:1, Val:7, Rest/bytes>>) 
  when Max =:= infinity; is_integer(Max), Max > 0 ->
    Acc1 = (Acc bsl 7) bor Val,
    decode(Acc1, maybe_decrease(Max), Rest);
decode(Acc, Max, <<0:1, Val:7, Rest/bytes>>) 
  when Max =:= infinity; is_integer(Max), Max > 0 ->
    Acc1 = (Acc bsl 7) bor Val,
    {ok, Acc1, Rest};
decode(_, _, _) ->
    {error, badarg}.

-ifdef(TEST).
decode_test_() ->
    [
     ?_test({ok, 16#00, _} = decode(<<16#00>>)),
     ?_test({ok, 16#7f, _} = decode(<<16#7f>>)),
     ?_test({ok, 16#80, _} = decode(<<16#81, 16#00>>)),
     ?_test({ok, 16#2000, _} = decode(<<16#c0, 16#00>>)),
     ?_test({ok, 16#3fff, _} = decode(<<16#ff, 16#7f>>)),
     ?_test({ok, 16#4000, _} = decode(<<16#81, 16#80, 16#00>>)),
     ?_test({ok, 16#1fffff, _} = decode(<<16#ff, 16#ff, 16#7f>>)),
     ?_test({ok, 16#200000, _} = decode(<<16#81, 16#80, 16#80, 16#00>>)),
     ?_test({ok, 16#08000000, _} = decode(<<16#c0, 16#80, 16#80, 16#00>>)),
     ?_test({ok, 16#0fffffff, _} = decode(<<16#ff, 16#ff, 16#ff, 16#7f>>)),
     ?_test({ok, 16#ffffffff, _} = decode(<<16#8f, 16#ff, 16#ff, 16#ff, 16#7f>>)),
     ?_test({error, badarg} = decode(<<16#ff>>)),
     ?_test({error, badarg} = decode32(<<16#ff, 16#ff, 16#ff, 16#ff, 16#ff, 16#00>>))
    ].
-endif.

maybe_decrease(infinity) ->
    infinity;
maybe_decrease(N) ->
    N - 1.






